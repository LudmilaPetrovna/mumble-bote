convert \
\( -size 4x4 gray:<(openssl rsa -in key.pem -outform DER | sha256sum | cut -c1-32 | xxd -r -p) \
   -auto-level -sigmoidal-contrast 6x50% \
   -resize 32x32! -filter point \
   -swirl 12 \) \
\( -size 4x4 gray:<(openssl rsa -in key.pem -outform DER | md5sum | cut -c1-32 | xxd -r -p) \
   -blur 0x1.5 \
   -resize 32x32! -filter point \) \
\( -size 4x4 gray:<(openssl rsa -in key.pem -outform DER | sha1sum | cut -c1-32 | xxd -r -p) \
   -motion-blur 0x10+45 \
   -resize 32x32! -filter point \) \
-set colorspace YCbCr -combine -colorspace RGB avatar.png
