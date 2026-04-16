



for($w=0;$w<16;$w++){
for($q=0;$q<16;$q++){
$c=$q+$w*16;
$bg=$c;
$fg=$c^0x80;
$NUM=sprintf("%02X",$c);


printf("\a\x1b[38;5;%dm\x1b[48;5;%dm%s\x1b[0m",$fg,$bg,$NUM);
}
print "\n";
}

