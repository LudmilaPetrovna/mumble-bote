#!/usr/bin/perl

use utf8;
use strict;
use Term::ANSIColor ":constants";
use File::Basename;
use feature 'state';
require "./utils.pl";

binmode(STDOUT,":utf8");
binmode(STDERR,":utf8");


my $botName='Bote';
my $botServer='brokensouls.wiki:64738';

my $currentChannel=0;
my $rootChannel=0;
my $session="0000000";
my %users=();

updateLogic();
processHello();
processMessage("test",'http://192.168.198.134/mumble_bote/avatar.jpg');
processMessage("test",'http://192.168.198.134/mumble_bote/avatar.jpg');

my $q;
for($q=0;$q<15;$q++){
processMessage("user".int(rand()*10),'message #'.($q+1));
}
processPresence("user",1,123);

processMessage("test",'https://www.youtube.com/watch?v=JrZSvnSlPjg');


while(<>){
chomp;
updateLogic();
processMessage("console",$_);
}

sub sendChatMessageText{
my($message,$channel_id,$session)=@_;
if(!defined $channel_id){$channel_id=$currentChannel;}
my $type='for '.RED.'CHANNEL '.$channel_id;
if(defined $session){$channel_id=-1;
$type='for '.GREEN.'PRIVATE $session';
}
print "Text message for ", $type, WHITE, ": ", BRIGHT_BLACK, "[",scalar localtime(),']', BRIGHT_GREEN,' ',$botName,WHITE,': ',BRIGHT_WHITE,$message,RESET,"\n";
}

sub sendChatMessageHTML{
my($message,$channel_id,$session)=@_;
if(!defined $channel_id){$channel_id=$currentChannel;}
my $type='for '.RED.'CHANNEL '.$channel_id;
if(defined $session){$channel_id=-1;
$type='for '.GREEN.'PRIVATE '.$session;
}
print "HTML message for ", $type, WHITE, ": ", BRIGHT_BLACK, "[",scalar localtime(),']', BRIGHT_GREEN,' ',$botName,WHITE,': ',BRIGHT_WHITE,$message,RESET,"\n";
}

sub sendChatStatus{
my $status=shift;
print "MY STATUS: $status\n";
}

sub sendChatSelfmute{
print "SELF MUTED\n";
}

sub setAvatar{
my $texture=shift;
print "SELF: setting avatar ".md5_hex($texture).", ".length($texture)." bytes\n";
# {. 'texture' => 'bin data',. 'session' => 35. }, 'MmbleProto::UserState'
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


