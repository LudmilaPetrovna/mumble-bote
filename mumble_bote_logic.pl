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

require "./decode_unknown.pl";

our $CONFIG;

my @history; # last 10 messages
my %activity;# last users for 24 hours
my $removeLinksRE="";

init();

sub init{
my @el=();
foreach(read_file('blacklist-links.txt')){
chomp;
if($_){
push(@el,$_);
}
}
$removeLinksRE=join("|",@el);
}


sub processHello{
my $date=localtime().' /// '.`ddate`;
chomp($date);
sendChatSelfmute();
sendChatStatus("connected at ".$date);
sendChatMessageText("Mumble chat sync service started at ".$date);

#set avatar
my $dir=dirname(__FILE__);
if(!-s('avatar.jpg')){
#`convert -colorspace gray -size 32x32 plasma:white-black -swirl -300 -negate -level 30%,70% -colorspace srgb avatar.jpg`;
`bash "$CONFIG->{avatar_gen}" "$CONFIG->{tlsCertFile}"`;
}
setAvatar(scalar read_file('avatar.jpg'));
}

sub processPresence{
my($from,$enter_exit_stay,$session)=@_;
if($main::useDebug){
print "Processing presence: ($from,$enter_exit_stay,$session)\n";
}
#adding to activity
if($from){
$activity{$from}=time();
}

if($enter_exit_stay==1){
my $now=time();
my $last24=$now-24*60*60;
my $history="Последние 10 сообщений чата:<br/><br/>\n\n".join("<br />\n",map{
my @t=localtime($_->[0]);
sprintf("<font color=\"gray\">[%02d:%02d:%02d]</font> <b>%s</b>: %s",$t[2],$t[1],$t[0],$_->[1],$_->[2])
}grep{$_->[0]>=$last24}@history);
my @old_users=grep{$activity{$_}<$last24}keys %activity;
foreach(@old_users){
delete $activity{$_};
}
my $activeUsers="<br /><br />\n\nЗа последние сутки тут были: ".join(", ",map{"<b>$_</b>"}sort keys %activity);

print Dumper(@history);
sendChatMessageHTML($history.$activeUsers,-1,$session);
}

}

sub processMessage{
my($from,$html,$channel_id,$is_private)=@_;
my $text=no_html($html);
$text=~s/\s+$//s;
my($cmd,$param)=split(/\s+/,$text,2);
$cmd=lc($cmd);
$cmd=~s/_//gs;
$cmd=~s/^!/%/gs;

if($main::useDebug){
print "Processing message: ($from,$text,$channel_id,$is_private)\n";
}

#don't talk to history:
if($text=~/Последние 10 сообщений чата:|За последние сутки тут были:/){return;}

#adding to activity
$activity{$from}=time();

#adding to history
if($text){
push(@history,[time(),$from,$text]);
if(@history>10){
splice(@history,0,@history-10);
}
}

if($cmd eq 'ping'){
sendChatMessageText("pong");
return;
}


if($text=~/что делать/i){
# fixme: better use userhash, instead of username
my $salt=join(":",(localtime())[3..8]).$from;
$salt=int(time()/3600/24).":".$from;
$text=~s/что делать[\?\.\:\s,]+//ig;
$text=~s/ - \d+\%$//gm;
$text=~s/<[^>]+>//gs;
print "what do salt:$salt, $text\n";
my @vers=map{
my $preproc=lc($_);
$preproc=~s/[^a-zа-яё0-9]//gs;
$preproc=~s/\s+/ /gs;

my $hh=sha1(encode_utf8($salt.$preproc.reverse($salt)));
my $nn=0;
my $q;
for($q=0;$q<5;$q++){
$nn^=unpack("N",substr($hh,$q*4));
}
[$_,int($nn/0xFFFFFFFF*146)]
}grep{length($_)>3}split(/\n/,$text);
if(@vers>1){
#int(rand()*146)
sendChatMessageHTML("<b>$from</b>: вам следует:".join("\n",map{"<br /><b>$_->[0]</b> - ".$_->[1].'%'}sort{$b->[1] <=> $a->[1]}@vers));
return;
}
}


# links preview
if($text=~/(https?:\/\/[^ <>\"\']+)/gs){
sendChatMessageHTML(getUrlTitle($1));
return;
}


}

sub text2html{
my $text=shift;
$text=~s/&/&amp;/gs;
$text=~s/</&lt;/gs;
$text=~s/>/&gt;/gs;
$text=~s/\n/<br>\n/gs;
return($text);
}

sub json2html{
my $text=shift;
$text=~s/&/&amp;/gs;
$text=~s/</&lt;/gs;
$text=~s/>/&gt;/gs;
$text=~s//&gt;/gs;
$text=~s/\\n/<br \/>\n/gs;
$text=~s/\\//gs;
return($text);
}


sub curl0{
my $link=shift;
my $ua = LWP::UserAgent->new;
use LWP::ConnCache;
$ua->conn_cache(LWP::ConnCache->new());
$ua->max_size(700000);
$ua->agent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36");
$ua->timeout(15);

my $rs=$ua->get($link);
my $page=$rs->decoded_content;
}

sub curl{
my $url=shift;
my $hash=md5_hex($url);
my $file='cache/'.substr($hash,0,2).'/'.substr($hash,2,2).'/'.substr($hash,4);
if(!-s($file)){
make_path(dirname($file));
sendPing();
`curl_chrome110 --max-redirs 2 -m15 -sL "$url" -o $file`;
}
if(!-s($file)){
return;
}
return(read_file($file));
}


sub isImageSafe{
my $filename=shift;
my $rs=decode_utf8(`file -z -b -k '$filename'`);
if($rs!~/(GIF|PNG|JPEG|Web\/P) image/){return;}
$rs=decode_utf8(`identify '$filename'`);
my $width=-1;
my $height=-1;
if($rs=~/\s(\d+)x(\d+)/){
($width,$height)=($1,$2);
}
if($width>2000 || $width<10 || $height>20000 || $height<10){return;}
return 1;
}

sub getImgTag{
my $src=shift;
my $tag="";
my $safe=isImageSafe($src);
if($safe){
my $tmp='/dev/shm/tmp-image-'.time().'-'.rand().rand().rand().rand().rand().".jpg";
`convert "$src"[0] -trim -resize 370x500\\\> -quality 50 "$tmp"`;
if(-s($tmp)){
$tag='<br /><img src="data:image/JPEG;base64,'.uri_escape(encode_base64(read_file($tmp),'')).'" />';
}
unlink($tmp);
}
return $tag;
}


sub getUrlTitle{
my $link=shift;
my $tag;
$link=~s/[,;\.:]+$//s;
my $page=curl($link);
my %props=();

if(!$page){
$page="хост лежит и не дышит";
return($page);
}

if($page=~/"videoId":"[^\"]+","title":"([^\"]+)",/is){
$props{title}=$1;
}

if($page=~/<titl[^>]+>([^<]+)/is){
$props{title}=$1;
}

if($page=~/"title":\{"simpleText":"([^\"]+)"\},"description":\{"simpleText":"([^\"]+)"/si){
$props{title}=json2html($1);
$props{desc}=json2html($2);
}

#rutracker
#if($page=~/postImg postImgAligned img-right\" title=\"([^<>\"]+)\"/){
#$props{img}=$1;
#}

while($page=~/(<(meta|link)[^>]+>)/gsi){
$tag=$1;
if($tag=~s/thumbnailUrl|image_src|twitter:image|og:image//si){
if($tag=~/(content|href)\s*=\s*\"([^<>\"]+)\"/si){
if(length($2)>length($props{img})){$props{img}=$2;}
}
}

if($tag=~s/\"description|og:description|twitter:description//si){
if($tag=~/content\s*=\s*\"([^<>\"]+)\"/si){
if(length($1)>length($props{desc})){$props{desc}=$1;}
}
}

if($tag=~s/twitter:title|og:title//si){
if($tag=~/content\s*=\s*\"([^<>\"]+)\"/si){
if(length($1)>length($props{title})){$props{title}=$1;}
}
}

if($tag=~s/og:site_name//si){
if($tag=~/content\s*=\s*\"([^<>\"]+)\"/si){
if(length($1)>length($props{site})){$props{site}=$1;}
}
}

}

print Dumper(\%props);

my $title=decode_entities(decodeUnknown($props{title}));
$title=~s/\s+/ /gs;

# preview time!
while($link=~/[\.\/](youtube\.com\/(embed\/|watch\?v=|shorts\/|live\/)|youtu\.be\/)([a-zA-Z\d_\-]{11})/gs){
#######https://i.ytimg.com/vi_webp/_____/mqdefault.webp
###my $url='https://i.ytimg.com/vi/'.$3.'/mqdefault.jpg';
$props{img}='https://i.ytimg.com/vi/'.$3.'/sddefault.jpg';
}

if($props{img}){
my $piclink=$props{img};
my $pic;
$props{img}=undef;
eval{
print "Loading pic $piclink\n";
$pic=curl($piclink);
#write_file("/dev/shm/fastpic.txt",$pic);
#if($piclink=~/fastpic\.org/ && $pic=~/(\Q$piclink\E\?md5=[^\"<>]+)/){
#print "Loading fastpic $1\n";
#$pic=curl($1);
#}
write_file("/dev/shm/temp.jpeg",$pic);
$props{img}=getImgTag('/dev/shm/temp.jpeg');
};
}



if(!$props{title}){
print "Perform file magic test\n";
write_file("/dev/shm/magicfiletest",$page);
$page=decode_utf8(`file -z -b -k /dev/shm/magicfiletest`);
$page=~s/\/dev\/\S+|, CORRUPTED//gs;
$page=~s/[\d\.]+KiB//gs;
$page=~s/\s+$//s;

if($page=~/image/i){
$page=decode_utf8(`identify /dev/shm/magicfiletest| tr "\n" " " | cut -d" " -f1-3`)." ".$page;
$page=~s/\/dev\S+|, CORRUPTED//gs;
$page=~s/[\d\.]+KiB//gs;
$page.=getImgTag('/dev/shm/magicfiletest');
}
return($page);
}

if($props{desc}){
$props{desc}='<br />'.decodeUnknown($props{desc});
}

$props{title}=decodeUnknown($props{title});
$props{desc}=~s/https?:\/\/(www\.)?($removeLinksRE)[^ <>]*/ХУЙ/gs;
$props{desc}=~s/ОГРН:?\s*\d+|ИНН:?\s*\d+|Erid:?\s*[^ <>]+/ПИЗДА/gsi;


return('<b>'.$props{title}.'</b>'.$props{img}.$props{desc});
}

print "Bot logic is okay!\n";
1
