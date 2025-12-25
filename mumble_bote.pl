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
use feature 'state';

require "./utils.pl";

# Usage: mumble_bote.pl "Bot name"

#options
my $useRandomNameSuffix=1;
my $botName=$ARGV[0]||'Bote'.($useRandomNameSuffix?" ".int(rand()*10000):"");
my $botServer='mumble.example.com:64738';
my $useDebug=0;

#path to certs
my $dir=dirname(__FILE__); # working dir same as script file
my $tlsCertFile=$dir.'/cert-'.md5_hex($botName).'.pem';
my $tlsKeyFile=$dir.'/key-'.md5_hex($botName).'.pem';

#good sosnolechka state
binmode(STDOUT,":utf8");
binmode(STDERR,":utf8");

#internal state
my $connected=0;
my $currentSession=0;
my $currentChannel=0;
my $rootChannel=0;
my %sessions=();

chdir $dir; # jump to working dir

#grab fresh Proto-file
if(!-s("Mumble.proto")){
`wget https://github.com/mumble-voip/mumble/raw/refs/heads/master/src/Mumble.proto`;
}

#create certs for current server and nickname, if need
if(!-s($tlsCertFile) || !-s($tlsKeyFile)){
`openssl req  -nodes -newkey rsa:2048 -x509  -keyout "$tlsKeyFile" -out "$tlsCertFile" -days 36500 -subj "/CN=example.com"`
}

updateLogic();

my @packet_types=(MumbleProto::Version,MumbleProto::UDPTunnel,MumbleProto::Authenticate,
MumbleProto::Ping,MumbleProto::Reject,MumbleProto::ServerSync,MumbleProto::ChannelRemove,MumbleProto::ChannelState,
MumbleProto::UserRemove,MumbleProto::UserState,MumbleProto::BanList,MumbleProto::TextMessage,MumbleProto::PermissionDenied,MumbleProto::ACL,MumbleProto::QueryUsers,MumbleProto::CryptSetup,MumbleProto::ContextActionModify,MumbleProto::ContextAction,MumbleProto::UserList,MumbleProto::VoiceTarget,MumbleProto::PermissionQuery,MumbleProto::CodecVersion,MumbleProto::UserStats,MumbleProto::RequestBlob,MumbleProto::ServerConfig,MumbleProto::SuggestConfig);
# @udp_types=qw/UDPVoiceCELTAlpha UDPPing UDPVoiceSpeex UDPVoiceCELTBeta UDPVoiceOpus/;

Google::ProtocolBuffers->parsefile("Mumble.proto",{generate_code=>'Mumble.pm',create_accessors=>1,follow_best_practice=>1});

if($useDebug){
$IO::Socket::SSL::DEBUG=3;
}


my $sock=IO::Socket::SSL->new(
SSL_cert_file=>$tlsCertFile,
SSL_key_file=>$tlsKeyFile,
PeerAddr=>$botServer,blocking=>0,SSL_verify_mode=>SSL_VERIFY_NONE) or die "Can't connect to $botServer: $SSL_ERROR\n\n";
my $sel=IO::Select->new($sock);

print "Connected to $botServer as $botName...\n";

my $started_time=time();
my $errors=0;
my $now;
my $passed_time;
my $last_ping=0;

sendPacket(0,MumbleProto::Version,{
version=>66304,
release=>"Broadcast chat",
os=>"perl",
os_version=>"linux"
});

while(1){

my $packet_head=readNBytes(6);
my $packet_payload="";
my $packet_payload_len=0;
my $msg;

$now=time();
$passed_time=$now;

if($errors>25){
die "do reconnect";
}

if($connected && $now-$last_ping>5){ #timeout, ping server!
sendPing();
$last_ping=$now;
}

if(length($packet_head)==0){
select(undef,undef,undef,.1);
next;
}

if(length($packet_head)!=6){
die;
$errors++;
next;
}

my($packet_type,$packet_len)=unpack("nN",$packet_head);
if($useDebug){
print "got packet ($packet_type,$packet_len)\n";
}
if($packet_type>25 || $packet_len>=0xFFFFFF){
die;
$errors++;
next;
}

if($packet_len>=0xFFFFFF){die "Too big packet: $packet_len (type: $packet_type)!";}

do{
$packet_payload.=readNBytes($packet_len-$packet_payload_len);
$packet_payload_len=length($packet_payload);
if($useDebug){
print "Got packet $packet_type ($packet_types[$packet_type]), len $packet_len bytes, we have ".$packet_payload_len."\n";
}
} while($packet_payload_len!=$packet_len);

if($useDebug){
open(hd,"|hexdump -C");
print hd substr($packet_payload,0,1024);
close(hd);
}

if($packet_type==1){ #MumbleProto::UDPTunnel
next;
}

$msg=undef;
eval{
$msg=$packet_types[$packet_type]->decode($packet_payload);
};
$errors=0;

# process packets
if(!$msg){next;}

if(ref($msg) eq "MumbleProto::CryptSetup"){ # contains binary data, so not display it
next;
}


if($useDebug){
print "We got from server $packet_type ($packet_types[$packet_type]) ($packet_len bytes), ".ref($msg).Dumper($msg);
}


if(ref($msg) eq "MumbleProto::Version"){
sendPacket(2,MumbleProto::Authenticate,{
username=>$botName,
password=>"",
#tokens=>'',
celt_versions=>-2147483637,
opus=>true
});
next;
}

if(ref($msg) eq "MumbleProto::CryptSetup" || ref($msg) eq "MumbleProto::CodecVersion"){
next;
}

if(ref($msg) eq "MumbleProto::Ping"){
next;
}

if(ref($msg) eq "MumbleProto::ServerConfig"){
if($useDebug){
print "Server config: ".$msg->{max_users}." users, ".($msg->{allow_html}?"with":"NO")." HTML, max msg size:".$msg->{message_length}.", max image:".$msg->{image_message_length}."\n";
}
next;
}

if(ref($msg) eq "MumbleProto::UserState"){
my $is_enter=exists $sessions{$msg->{session}}?0:1;
if(!$connected){$is_enter=2;}
if(defined $msg->{name}){
$sessions{$msg->{session}}=decode_utf8($msg->{name});
}
processPresence($sessions{$msg->{session}},$is_enter,$msg->{session});
if($msg->{session}==$currentSession && defined $msg->{channel_id}){
$currentChannel=$msg->{channel_id};
if($useDebug){
print "Bot changed channel to $currentChannel\n";
}
#fix me
#bot don't know own session during init state (before "connected")
}

next;
}

if(ref($msg) eq "MumbleProto::UserRemove"){
delete $sessions{$msg->{session}};
processPresence($sessions{$msg->{session}},0,$msg->{session});
if($currentSession == $msg->{session}){
die "we was kicked/banned/removed: \"".$msg->{reason}."\"";
}
next;
}

if(ref($msg) eq "MumbleProto::Reject"){
die $msg->{reason};
next;
}

if(ref($msg) eq "MumbleProto::TextMessage" && exists $sessions{$msg->{actor}}){
updateLogic();
processMessage($sessions{$msg->{actor}},decode_utf8($msg->{message}),$msg->{channel_id}->[0],$msg->{session}->[0]);
next;
}

if(ref($msg) eq "MumbleProto::ChannelState"){
if(!exists $msg->{parent}){
#$msg->{can_enter}!=0 && $msg->{is_enter_restricted}!=1 && 
$rootChannel=$msg->{channel_id};
if($useDebug){
print "Setting ROOT to $rootChannel\n";
}
}
next;
}


if(ref($msg) eq "MumbleProto::ServerSync"){
my $welcome=$msg->{welcome_text}." (max bandwidth: ".$msg->{max_bandwidth}.")";
$welcome=~s/<[^>]+>//gs;
if($useDebug){
print "Welcome message: $welcome\n";
}
$connected=1;
$currentSession=$msg->{session};

updateLogic();
processHello();
next;
}



}

sub sendChatMessageText{
my($message,$channel_id,$session_id)=@_;
my $data={message=>text2html($message)};
if(defined $session_id){
$data->{session}=[$session_id];
} else {
if(!defined $channel_id || $channel_id<0){$channel_id=$currentChannel;}
$data->{channel_id}=$channel_id;
}

if(!$connected || !$sock){die "We not connected yet!";}
sendPacket(11,MumbleProto::TextMessage,$data);
}

sub sendChatMessageHTML{
my($message,$channel_id,$session_id)=@_;
my $data={message=>$message};
if(defined $session_id){
$data->{session}=[$session_id];
} else {
if(!defined $channel_id || $channel_id<0){$channel_id=$currentChannel;}
$data->{channel_id}=$channel_id;
}
sendPacket(11,MumbleProto::TextMessage,$data);
}


sub sendChatStatus{
my($text)=@_;
$text=text2html($text);
sendPacket(9,MumbleProto::UserState,{session=>$currentSession,comment=>$text});
}

sub sendChatSelfmute{
my $muted=shift;
if(!defined $muted){$muted=1;}
sendPacket(9,MumbleProto::UserState,{session=>$currentSession,self_mute=>1,self_deaf=>1});
}

sub readNBytes{
my $size=shift;
my $buf;
my $data="";
my $need;
my $actual;
my $timeout=2;
my $started=time();
while(1){
$need=$size-length($data);
if($need==$size && time()-$started>=$timeout){return;}
#print "we need $need\n";
$sock->blocking(0);
#$sel->can_read();
$actual=sysread($sock,$buf,$need);
if(!defined $actual){
#print "disconnected???\n";
}
#print "Actual: $actual\n";
if($actual==0){
select(undef,undef,undef,.1); # sleep .1 second and read next chunk
next;
}
$data.=$buf;
if($actual==$need){
last;
}
}
return($data);
}


sub varint{
my $buf=shift;
my $len=length($buf);
my $p=0;
my $ret=0;
my $b0=unpack("C",substr($buf,0,1));
my $adv=0;
if(($b0&0x80)==0){
$adv=0;
$ret=$b0&0x7F;
}

if(($b0&0xC0)==0x80){
$adv=1;
$ret=$b0&0x3F;
}

if(($b0&0xE0)==0xC0){
$adv=2;
$ret=$b0&0x1F;
}

if(($b0&0xF0)==0xE0){
$adv=3;
$ret=$b0&0x0F;
}

if(($b0&0xFC)==0xF0){
$adv=4;
$ret=0;
}
if(($b0&0xFC)==0xF4){
$adv=8;
$ret=0;
}
$p++;

while($p<$len && $adv--){
$ret<<=8;
$ret|=unpack("C",substr($buf,$p,1));
$p++;
}
return($ret,$p);
}


sub setAvatar{
my $texture=shift;
if($useDebug){
print "SELF: setting avatar ".md5_hex($texture).", ".length($texture)." bytes\n";
}
sendPacket(9,MumbleProto::UserState,{texture=>$texture,session=>$currentSession});
}

sub sendPing{
sendPacket(3,MumbleProto::Ping,{timestamp=>($now-$started_time)."000000"});
}

sub sendPacket{
my $id=shift;
my $type=shift;
my $data=shift;
my $msg=$type->encode($data);
$msg=pack("nN",$id,length($msg)).$msg;

my $offset=0;
my $actual=undef;
my $mlen=length($msg);
while($mlen!=$offset){
$sel->can_write();
$actual=syswrite($sock,$msg,$mlen-$offset,$offset);
if(!defined $actual){
die "Can't write to socket!";
}
$offset+=$actual;
}
if($useDebug){
print "Sending packet: ".Dumper($data);
}
}

sub updateLogic{
state $lastInited=-1;
my $logicFile=dirname(__FILE__).'/mumble_bote_logic.pl';
my $mtime=(stat($logicFile))[9];
if($mtime>$lastInited){
do $logicFile;
$lastInited=$mtime;
print "Updated logic to ".localtime($lastInited)."\n";
}
}

sub processHello{
print "STUB IS USED!!!\n";
}

sub processPresence{
print "STUB IS USED!!!\n";
}

sub processMessage{
print "STUB IS USED!!!\n";
}

