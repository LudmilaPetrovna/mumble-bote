use HTML::Entities;
use Digest::CRC qw(crc64 crc32 crc16);

sub no_html{
my $text=shift;
$text=decode_entities($text);
$text=~s/<(p|br)[^>]*>/\n/gs;
$text=~s/<[^>]*>//gs;
return($text);
}

sub text2html{
my $text=shift;
$text=~s/&/&amp;/gs;
$text=~s/</&lt;/gs;
$text=~s/>/&gt;/gs;
$text=~s/\n/<br \/>\n/gs;
return($text);
}

sub json2html{
my $text=shift;
$text=~s/\\n/\n/gs;
$text=~s/\\//gs;
return(text2html($text));
}

sub get_human_date{
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($_[0]);
return(sprintf("%.4d-%.2d-%.2d",$year+1900,$mon+1,$mday));
}
sub get_human_date_time{
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($_[0]);
return(sprintf("[%.4d-%.2d-%.2d %02d:%02d:%02d]",$year+1900,$mon+1,$mday,$hour,$min,$sec));
}


sub get_color_text{
my $fg=shift;
my $text=shift;
my $bg=$fg^0x80;
return(sprintf("\x1b[38;5;%dm\x1b[48;5;%dm%s\x1b[0m",$fg||7,$bg,$text));
}


sub get_colorized_text{
my $text=shift;
my $crc=crc32($text);
my $fg=($crc&0xFF);
return(get_color_text($fg,$text));
}


1




