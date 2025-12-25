#!/bin/bash

ddate
file deps_test.sh
for q in {jpg,gif,png,webp};do
convert -size 100x500 plasma: test.$q
identify test.$q
rm -f test.$q
done

curl --version
curl_chrome110 --version

echo -e "\n\nPerl modules testing..."
perl -e 'use Digest::SHA1'
perl -e 'use File::Slurp'
perl -e 'use Google::ProtocolBuffers'
perl -e 'use HTML::Entities'
perl -e 'use IO::Socket::SSL'
perl -e 'use JSON'
perl -e 'use LWP::UserAgent'
perl -e 'use URI::Escape'
echo "Testing done"
