use strict;
use warnings;
use DBI;
use GD;
use Time::Local;
use POSIX qw(strftime);

# ---------------- config ----------------

my $IMG_W = 1440;
my $IMG_H = 600;
my $GRAPH_H = 260;
my $TIME_H  = 40;

# ---------------- args ------------------

my ($dbfile, $server, $from_str) = @ARGV;
die "usage: $0 db.sqlite host:port [\"YYYY-MM-DD HH:MM\"]\n"
    unless $dbfile && $server;

# ---------------- time window -----------

my $to_ts = time();
my $from_ts;

if ($from_str) {
    if ($from_str =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+)$/) {
        $from_ts = timelocal(0, $5, $4, $3, $2-1, $1);
        $to_ts   = $from_ts + 86400;
    } else {
        die "bad time format\n";
    }
} else {
    $from_ts = $to_ts - 86400;
}

# ---------------- db --------------------

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=$dbfile", "", "",
    { RaiseError => 1 }
);

my $sth = $dbh->prepare(q{
    SELECT ts, ping_ms, users
    FROM samples
    WHERE server = ?
      AND ts BETWEEN ? AND ?
    ORDER BY ts
});

$sth->execute($server, $from_ts, $to_ts);

# ---------------- buckets ---------------

my @ping_sum;
my @ping_cnt;
my @ping_undef;

my @user_sum;
my @user_cnt;
my @user_undef;

while (my $r = $sth->fetchrow_hashref) {
    my $idx = int(($r->{ts} - $from_ts) / 60);
    next if $idx < 0 || $idx >= 1440;

    if (defined $r->{ping_ms}) {
        $ping_sum[$idx] += $r->{ping_ms};
        $ping_cnt[$idx]++;
    } else {
        $ping_undef[$idx]++;
    }

    if (defined $r->{users}) {
        $user_sum[$idx] += $r->{users};
        $user_cnt[$idx]++;
    } else {
        $user_undef[$idx]++;
    }
}

# ---------------- normalize -------------

sub normalize {
    my ($sum, $cnt) = @_;
    my @vals;

    my ($min, $max);

    for my $i (0..1439) {
        next unless $cnt->[$i];
        my $v = $sum->[$i] / $cnt->[$i];
        $vals[$i] = $v;

        $min = $v if !defined($min) || $v < $min;
        $max = $v if !defined($max) || $v > $max;
    }

    $min //= 0;
    $max //= 1;

    return (\@vals, $min, $max);
}

my ($ping_vals, $ping_min, $ping_max) = normalize(\@ping_sum, \@ping_cnt);
my ($user_vals, $user_min, $user_max) = normalize(\@user_sum, \@user_cnt);


# ---------------- image -----------------

my $img = GD::Image->new($IMG_W, $IMG_H);
$img->saveAlpha(1);
$img->alphaBlending(1);

my $white = $img->colorAllocate(255,255,255);
my $green = $img->colorAllocate(0,180,0);
my $blue  = $img->colorAllocate(0,0,200);
my $red   = $img->colorAllocate(200,0,0);
my $grid  = $img->colorAllocateAlpha(0,0,0,100);

$img->filledRectangle(0,0,$IMG_W,$IMG_H,$white);

# ---------------- grid ------------------

for my $x (0..1439) {
    if ($x % 60 == 0) {
        $img->line($x,0,$x,$IMG_H-$TIME_H,$grid);
    }
}

for my $y (0, $GRAPH_H) {
    $img->line(0,$y,$IMG_W,$y,$grid);
}

# ---------------- draw graph ------------

sub draw_graph {
    my ($vals, $undef, $max, $y0, $color) = @_;

    for my $x (0..1439) {
        if ($undef->[$x]) {
#            $img->setPixel($x, $y0 + $GRAPH_H/2, $red);
        $img->line($x,$y0,$x,$y0+$GRAPH_H,$red);

            next;
        }
        next unless defined $vals->[$x];

        my $h = int(($vals->[$x] / $max) * ($GRAPH_H-2));
        my $y = $y0 + $GRAPH_H - 1 - $h;

#        $img->setPixel($x, $y, $color);
        $img->line($x,$y,$x,$y0+$GRAPH_H,$color);
    }
}

sub draw_vscale {
    my ($min, $max, $y0, $label_fmt) = @_;

    my $mid = ($min + $max) / 2;

    my @labels = (
        [ $max, $y0 + 2 ],
        [ $mid, $y0 + $GRAPH_H/2 - 6 ],
        [ $min, $y0 + $GRAPH_H - 12 ],
    );

    for (@labels) {
        my ($v, $y) = @$_;
        my $txt = sprintf($label_fmt, $v);
        $img->string(gdSmallFont, 2, $y, $txt, $grid);
    }
}

draw_vscale($ping_min, $ping_max, 0, "%.1f ms");
draw_vscale($user_min, $user_max, $GRAPH_H, "%.0f");

draw_graph($ping_vals, \@ping_undef, $ping_max, 0, $green);
draw_graph($user_vals, \@user_undef, $user_max, $GRAPH_H, $blue);

# ---------------- time scale ------------

for my $x (0..1439) {
    next unless $x % 60 == 0;
    my $ts = $from_ts + $x * 60;
    my $label = strftime("%H:%M", localtime($ts));
    $img->string(gdSmallFont, $x+2, $IMG_H-$TIME_H+10, $label, $grid);
}

# ---------------- output ----------------

binmode STDOUT;
print $img->png;
