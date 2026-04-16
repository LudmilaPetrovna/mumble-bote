#!/usr/bin/perl

use strict qw/vars refs/;
use utf8;
use JSON;
use Encode;
use Google::ProtocolBuffers;
use IO::Socket::SSL;
use IO::Select;
use Digest::MD5 "md5_hex";
use Digest::SHA1 "sha1";
use Data::Dumper;
use File::Slurp;
use File::Path qw(make_path remove_tree);
use File::Basename;
use MIME::Base64;
use URI::Escape qw( uri_escape );
use LWP::UserAgent;
use HTML::Entities;
use Time::HiRes qw(gettimeofday);
use feature 'state';

require "./utils.pl";
require "./mumble_bote_simple_console.pl";

#good sosnolechka state
binmode(STDOUT,":utf8");
binmode(STDERR,":utf8");

my @packet_types=(MumbleProto::Version,MumbleProto::UDPTunnel,MumbleProto::Authenticate,
MumbleProto::Ping,MumbleProto::Reject,MumbleProto::ServerSync,MumbleProto::ChannelRemove,MumbleProto::ChannelState,
MumbleProto::UserRemove,MumbleProto::UserState,MumbleProto::BanList,MumbleProto::TextMessage,MumbleProto::PermissionDenied,MumbleProto::ACL,MumbleProto::QueryUsers,MumbleProto::CryptSetup,MumbleProto::ContextActionModify,MumbleProto::ContextAction,MumbleProto::UserList,MumbleProto::VoiceTarget,MumbleProto::PermissionQuery,MumbleProto::CodecVersion,MumbleProto::UserStats,MumbleProto::RequestBlob,MumbleProto::ServerConfig,MumbleProto::SuggestConfig);
# @udp_types=qw/UDPVoiceCELTAlpha UDPPing UDPVoiceSpeex UDPVoiceCELTBeta UDPVoiceOpus/;

Google::ProtocolBuffers->parsefile("Mumble.proto",{generate_code=>'Mumble.pm',create_accessors=>1,follow_best_practice=>1});

if(!$ARGV[0]){
die "Usage:\n".__FILE__." [logfile.mumble]\n\n";
}


my $currentSession=0;
my $currentChannel=0;
my $rootChannel=0;
my %sessions=();


my($packet_type,$packet_len,$packet_timestamp);
my $packet_payload;
my $msg;
open(ii,$ARGV[0]);

while(!eof(ii)){
read(ii,$msg,12);
($packet_timestamp,$packet_type,$packet_len)=unpack("III",$msg);
read(ii,$packet_payload,$packet_len);


if($packet_type>25 || $packet_len>=0xFFFFFF){
die "Wrong type of packet or packet too large!";
}

if($packet_len>=0xFFFFFF){die "Too big packet: $packet_len (type: $packet_type)!";}

open(hd,"|hexdump -C");
print hd substr($packet_payload,0,1024);
close(hd);

if($packet_type==1){ #MumbleProto::UDPTunnel
next;
}

$msg=undef;
eval{
$msg=$packet_types[$packet_type]->decode($packet_payload);
};

# process packets
if(!$msg){next;}

print "We got from server $packet_type ($packet_types[$packet_type]) ($packet_len bytes), ".ref($msg).Dumper($msg);


if(ref($msg) eq "MumbleProto::CryptSetup"){ # contains binary data, so not display it
next;
}


if(ref($msg) eq "MumbleProto::CryptSetup" || ref($msg) eq "MumbleProto::CodecVersion"){
next;
}

if(ref($msg) eq "MumbleProto::Ping"){
next;
}




if(ref($msg) eq "MumbleProto::UserRemove"){
processPresence(exists $msg->{name}?$msg->{name}:$sessions{$msg->{session}},0,$msg->{session});
if($currentSession == $msg->{session}){
die "we was kicked/banned/removed: \"".$msg->{reason}."\"";
}
delete $sessions{$msg->{session}};
next;
}



if(ref($msg) eq "MumbleProto::UserState"){
my $is_enter=exists $sessions{$msg->{session}}?2:1;
if(defined $msg->{name}){
$sessions{$msg->{session}}=decode_utf8($msg->{name});
}
processPresence($sessions{$msg->{session}},$is_enter,$msg->{session});
if($msg->{session}==$currentSession && defined $msg->{channel_id}){
$currentChannel=$msg->{channel_id};
}
next;
}



if(ref($msg) eq "MumbleProto::TextMessage" && exists $sessions{$msg->{actor}}){
processMessage($sessions{$msg->{actor}},decode_utf8($msg->{message}),$msg->{channel_id}->[0],$msg->{session}->[0]);
next;
}


if(ref($msg) eq "MumbleProto::ServerSync"){
my $welcome=$msg->{welcome_text}." (max bandwidth: ".$msg->{max_bandwidth}.")";
$welcome=~s/<[^>]+>//gs;
$currentSession=$msg->{session};
processHello();
next;
}


}




sub setAvatar{}
sub sendPacket{}
sub sendChatSelfmute{}
sub sendChatStatus{}
sub sendChatMessageHTML{}
sub sendChatMessageText{}
