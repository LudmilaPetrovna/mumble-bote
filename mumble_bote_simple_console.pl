#!/usr/bin/perl

use strict;
use utf8;
use JSON;
use Encode;
use Digest::MD5 "md5_hex";
use Digest::SHA1 "sha1";
use Data::Dumper;
use File::Slurp;
use File::Path qw(make_path remove_tree);
use File::Basename;
use MIME::Base64;
use URI::Escape "uri_escape";
use LWP::UserAgent;
use HTML::Entities;
use Digest::CRC qw(crc64 crc32 crc16);

require "./decode_unknown.pl";

our $CONFIG;

my $COLOR_DATETIME=0x1A;
my $COLOR_MESSAGE=0x7C;
my $COLOR_PRESENCE=0x3F;


sub processHello{
sendChatSelfmute();
}

sub processPresence{
my($from,$enter_exit_stay,$session)=@_;
print "".get_color_text($COLOR_DATETIME,get_human_date_time(time())).get_color_text($COLOR_PRESENCE,": presence $enter_exit_stay ").get_colorized_text($from)."\n";
logme("presence $enter_exit_stay $from");
}

sub processMessage{
my($from,$html,$channel_id,$is_private)=@_;
my $text=no_html($html);
$text=~s/\s+$//s;

print "".get_color_text($COLOR_DATETIME,get_human_date_time(time())).get_color_text($COLOR_MESSAGE,": message from ").get_colorized_text($from).get_color_text($COLOR_MESSAGE,": ").get_colorized_text($text)."\n";
logme("msg from $from: $text");
}


sub logme{
open(ll,">>log");
binmode(ll,":utf8");
my $out="".get_human_date_time(time()).": ".join(", ",@_)."\n";
print ll $out;
close(ll);
}


print "Bot logic is okay!\n";
1
