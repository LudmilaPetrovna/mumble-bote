TMP="tmp" && mkdir -p "$TMP"

openssl rsa -in "$1" -outform DER 2>/dev/null | openssl dgst -sha256 -binary | head -c16 > "$TMP/Y.bin"
openssl rsa -in "$1" -outform DER 2>/dev/null | openssl dgst -md5    -binary | head -c16 > "$TMP/Cb.bin"
openssl rsa -in "$1" -outform DER 2>/dev/null | openssl dgst -sha1   -binary | head -c16 > "$TMP/Cr.bin"

md5sum tmp/*

convert \
\( -size 4x4 -depth 8 gray:"$TMP/Y.bin" \
   -sigmoidal-contrast 6x50% -auto-level \
   -filter point -resize 32x32 \
   -swirl 8 \) \
\( -size 4x4 -depth 8 gray:"$TMP/Cb.bin" -normalize \
   -filter point -resize 32x32 -blur 0x1.5 \) \
\( -size 4x4 -depth 8 gray:"$TMP/Cr.bin" -normalize \
   -filter point -resize 32x32 -motion-blur 0x6+45 \) \
-set colorspace YCbCr -combine -colorspace RGB avatar.jpg

rm -rvf "$TMP/"{Y.bin,Cb.bin,Cr.bin}

