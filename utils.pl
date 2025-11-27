use HTML::Entities;

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

1
