TMP="tmp" && mkdir -p "$TMP"

openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -sha256 -binary | head -c16 > "$TMP/Y.bin"
openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -md5    -binary | head -c16 > "$TMP/Cb.bin"
openssl rsa -in key.pem -outform DER 2>/dev/null | openssl dgst -sha1   -binary | head -c16 > "$TMP/Cr.bin"

hex2dec() { printf "%d\n" "0x$1"; }

STYLE=$(openssl dgst -sha1 -binary "$1" | xxd -p -c20)
B0=${STYLE:0:2}   # swirl
B1=${STYLE:2:2}   # wave amp
B2=${STYLE:4:2}   # wave len
B3=${STYLE:6:2}   # blur
B4=${STYLE:8:2}   # motion len
B5=${STYLE:10:2}  # motion angle
echo converting $B0
SWIRL=$(hex2dec "$B0")
echo converting $B1
WAVE_A=$(($(hex2dec "$B1")%8))
echo converting $B2
WAVE_L=$(($(hex2dec "$B2")%8))
echo converting $B3
BLUR=$(printf "%.1f" "$(echo $(hex2dec $B3) / 32 | bc -l)") #"
echo blur $BLUR
echo converting $B4
MBLEN=$(hex2dec "$B4")
echo converting $B5
MBANG=$(hex2dec "$B5")

convert \
\( -depth 8 -size 4x4 gray:"$TMP/Y.bin"  \
   -auto-level -normalize -sigmoidal-contrast 6x50% \
   -filter point -resize 32x32! \) \
\( -depth 8 -size 4x4 gray:"$TMP/Cb.bin" \
   -filter point -resize 32x32! -blur 0x$BLUR \) \
\( -depth 8 -size 4x4 gray:"$TMP/Cr.bin" \
   -filter point -resize 32x32! -motion-blur 0x${MBLEN}+${MBANG} \) \
-set colorspace YCbCr -combine -colorspace RGB \
 \( +clone \) +append \
  \
  \( +clone \) -append \
 -wave ${WAVE_A}x${WAVE_L}  -extent 32x32+16+16 +repage \
-swirl $((-SWIRL)) \
avatar.jpg

#

#-wave  \
rm -rvf "$TMP/"{Y.bin,Cb.bin,Cr.bin}
