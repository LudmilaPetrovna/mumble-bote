TMP=$(mktemp -d) && \
openssl rsa -in key.pem -outform DER 2>/dev/null >$TMP/k.der && \
openssl dgst -sha256 -binary $TMP/k.der | head -c16 >$TMP/Y && \
openssl dgst -md5    -binary $TMP/k.der | head -c16 >$TMP/Cb && \
openssl dgst -sha1   -binary $TMP/k.der | head -c16 >$TMP/Cr && \
H=$(openssl dgst -sha1 -binary $TMP/k.der | xxd -p | tr -d '\n') && \
SW=$((16#${H:0:2}-128)) && \
WA=$((16#${H:2:2}%4)) && \
WL=$((16#${H:4:2}%4)) && \
BL=$((16#${H:6:2}%4)) && \
ML=$((16#${H:8:2}%4)) && \
MA=$((16#${H:10:2}%4)) && \
convert \
\( -depth 8 -size 4x4 gray:$TMP/Y  -auto-level -sigmoidal-contrast 6x50% -filter point -resize 32x32! \) \
\( -depth 8 -size 4x4 gray:$TMP/Cb -filter point -resize 32x32! -blur 0x$BL \) \
\( -depth 8 -size 4x4 gray:$TMP/Cr -filter point -resize 32x32! -motion-blur 0x${ML}+${MA} \) \
-set colorspace YCbCr -combine -colorspace RGB \
\( +clone \) +append \( +clone \) -append \
-wave ${WA}x${WL} \
-gravity center -crop 32x32+0+0 +repage \
-swirl $((-SW)) \
-modulate 100,160,100 \
-filter point -resize 32x32! \
avatar.png


#rm -rf "$TMP"
#