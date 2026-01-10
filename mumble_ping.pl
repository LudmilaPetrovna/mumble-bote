#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use Time::HiRes qw(time usleep);
use Net::Ping;
use Data::Dumper;
use File::Slurp;
use DBI;
use POSIX qw(setsid);


sub init_db{
    my ($dbfile) = @_;
    print STDERR "Opening $dbfile database...\n";
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$dbfile",
        "",
        "",
        {
            RaiseError => 1,
            AutoCommit => 1,
        }
    );

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS samples (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            ts        INTEGER NOT NULL,
            server    TEXT NOT NULL,
            ping_ms   REAL,
            users     INTEGER,
            max_users INTEGER
        )
    });

    $dbh->do(q{
        CREATE INDEX IF NOT EXISTS idx_samples_server_ts
        ON samples(server, ts)
    });

    my $sth = $dbh->prepare(q{
        INSERT INTO samples (ts, server, ping_ms, users, max_users)
        VALUES (?, ?, ?, ?, ?)
    });

    return($dbh,$sth);
}

sub run_daemon {
    my (%cfg) = @_;
    my ($dbh,$sth) = init_db($cfg{dbfile});
    my $server_id = "$cfg{host}:$cfg{port}";
    print STDERR "Pinging $server_id and save to database...\n";

    while (1) {
        my $t0 = time();

        my $res = check_mumble_server(
            host => $cfg{host},
            port => $cfg{port},
	    udp_count => 1,
	    icmp_count => 0,
	    timeout => 5
        );

        if ($res && $res->{max_users}) {
print "".int($t0).": $server_id ($res->{users}/$res->{max_users}), $res->{udp_ping_ms}{min}ms\n";
    $sth->execute(
        int($t0),
        $server_id,
        $res->{udp_ping_ms}{min},
        $res->{users},
        $res->{max_users},
    );

        } else {
    $sth->execute(
        int($t0),
        $server_id,
	undef,undef,undef
            );
        }
sleep(1);

    }
}



sub decode_mumble_version {
    my ($v) = @_;
    return undef unless defined $v;

    my $major = ($v >> 16) & 0xff;
    my $minor = ($v >> 8)  & 0xff;
    my $patch = $v & 0xff;

    return "$major.$minor.$patch";
}

sub check_mumble_server {
    my (%opts) = @_;

    my $host       = $opts{host}       // '127.0.0.1';
    my $port       = $opts{port}       // 64738;
    my $timeout    = $opts{timeout}    // 1;
    my $udp_count  = $opts{udp_count}  // 5;
    my $icmp_count = $opts{icmp_count} // 5;

    #
    # UDP legacy ping
    #
    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'udp',
    ) or die "UDP socket error: $!";

    my @udp_rtt;
    my ($version_i, $users, $max_users, $bandwidth, $ip);

    for (1 .. $udp_count) {
        my $ts = int(time() * 1_000_000);   # microseconds
        my $packet = pack("N Q>", 0, $ts);

        $sock->send($packet);

        my $rin = '';
        vec($rin, fileno($sock), 1) = 1;

        unless (select($rin, undef, undef, $timeout)) {
            next;
        }

        my $resp;
        $sock->recv($resp, 1024);

        my $now_us = int(time() * 1_000_000);

        next unless length($resp) >= 24;

        my (
            $v,
            $ts_echo,
            $u,
            $u_max,
            $bw
        ) = unpack("N Q> N N N", $resp);

        push @udp_rtt, ($now_us - $ts_echo) / 1000.0;

        $version_i = $v;
        $users     = $u;
        $max_users = $u_max;
        $bandwidth = $bw;

        usleep(100_000);
    }

    @udp_rtt = sort { $a <=> $b } @udp_rtt;

    #
    # ICMP ping via /bin/ping
    #
    my @icmp_rtt=();
if($icmp_count>0){
    my $cmd = sprintf(
        "ping -n -c %d -W %d %s 2>/dev/null",
        $icmp_count,
        $timeout,
        $host
    );

    if (open my $ph, '-|', $cmd) {
        while (<$ph>) {
if(/PING \S+ \((\d+\.\d+\.\d+\.\d+)\)/){
$ip=$1;
}
            if (/time=([\d.]+)\s*ms/) {
                push @icmp_rtt, $1;
            }
        }
        close $ph;
    }

    @icmp_rtt = sort { $a <=> $b } @icmp_rtt;
}

    return {ip=>$ip,
        host      => $host,
        port      => $port,

        version   => decode_mumble_version($version_i),
        users     => $users,
        max_users => $max_users,
        bandwidth => $bandwidth,

        udp_ping_ms => {
            min => $udp_rtt[0],
            max => $udp_rtt[-1],
        },

        icmp_ping_ms => {
            min => $icmp_rtt[0],
            max => $icmp_rtt[-1],
        },
    };
}

#print Dumper(check_mumble_server("host"=>"127.0.0.1","port"=>64777));

my($addr,$database)=@ARGV;
my($host,$port);
if(!$addr){die "Usage: ".__FILE__." mumble://127.0.0.1:64738 [database.sqlite]\n\n";}

if($addr=~/mumble:\/\/([^ :]+):(\d+)/){
($host,$port)=($1,$2);
}

if(defined $database && $database=~/\.sqlite/){
run_daemon(host=>$host,port=>$port,dbfile=>$database);
} else {

my $res=Dumper(check_mumble_server(host=>$host,port=>$port));
#rite_file('results/'.$host.'-'.$port,$res);
print $res;
}

