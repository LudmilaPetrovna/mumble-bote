TMP="tmp" && mkdir -p "$TMP"
openssl rsa -in "$1" -outform DER 2>/dev/null | sha1sum | cut -c1-15 > "$TMP/Y.bin"
openssl rsa -in "$1" -outform DER 2>/dev/null | sha256sum | cut -c1-15 > "$TMP/Cr.bin"
openssl rsa -in "$1" -outform DER 2>/dev/null | md5sum | cut -c1-15 > "$TMP/Cb.bin"

convert \
\( -depth 8 -colorspace gray -size 4x4 \
   gray:"$TMP/Y.bin" \
   -auto-level -sigmoidal-contrast 6x50% \
   -resize 32x32! -filter point -swirl 10 \) \
\( -colorspace gray -depth 8 -size 4x4 \
   gray:"$TMP/Cr.bin" -normalize \
   -resize 32x32! -filter point \
   -blur 0x1.2  \) \
\( -colorspace gray -depth 8 -size 4x4 \
   gray:"$TMP/Cb.bin" -normalize \
   -resize 32x32! -filter point \
   -motion-blur 0x8+45 \) \
-set colorspace YCbCr -combine -colorspace RGB avatar.jpg


#cat "$TMP/Cr.bin"
#convert -colorspace gray -depth 8 -size 4x4  gray:"$TMP/Cr.bin" -normalize -resize 32x32! avatar.jpg


#rm -rvf "$TMP/"{Y.bin,Cb.bin,Cr.bin}
