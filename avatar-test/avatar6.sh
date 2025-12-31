openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -sha256 -binary | head -c16 > Y.bin
openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -md5    -binary | head -c16 > Cb.bin
openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -sha1   -binary | head -c16 > Cr.bin

convert \
\( -size 4x4 -depth 8 gray:Y.bin \
   -auto-level -sigmoidal-contrast 6x50% \
   -filter point -resize 32x32 \
   -swirl 8 \) \
\( -size 4x4 -depth 8 gray:Cb.bin \
   -blur 0x1.5 \
   -filter point -resize 32x32 \) \
\( -size 4x4 -depth 8 gray:Cr.bin \
   -motion-blur 0x6+45 \
   -filter point -resize 32x32 \) \
-set colorspace YCbCr -combine -colorspace RGB avatar.png
