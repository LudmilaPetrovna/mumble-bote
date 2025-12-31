convert \
\( xc: -size 4x4 \
   "$(openssl rsa -in key.pem -outform DER 2>/dev/null | sha256sum | cut -c1-32)" \
   -random-threshold 0x100 \
   -auto-level -sigmoidal-contrast 6x50% \
   -resize 32x32! -filter point -swirl 10 \) \
\( xc: -size 4x4 \
   "$(openssl rsa -in key.pem -outform DER 2>/dev/null | md5sum | cut -c1-32)" \
   -random-threshold 0x100 \
   -blur 0x1.2 -resize 32x32! -filter point \) \
\( xc: -size 4x4 \
   "$(openssl rsa -in key.pem -outform DER 2>/dev/null | sha1sum | cut -c1-32)" \
   -random-threshold 0x100 \
   -motion-blur 0x8+45 -resize 32x32! -filter point \) \
-set colorspace YCbCr -combine -colorspace RGB avatar.png
