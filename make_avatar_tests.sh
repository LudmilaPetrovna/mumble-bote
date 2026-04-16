
for q in {1..10};do
openssl req -nodes -newkey rsa:2048 -x509 -keyout tmp-avatar.key -out tmp-avatar.cert -sha1 -set_serial 1 -days 1 -subj "/CN=test"

for a in {5..8}; do

bash ./avatar-test/avatar${a}.sh tmp-avatar.key
mv avatar.jpg tmp-avatar-$q-$a.jpg

done
done

montage -background green -geometry 32x32+1+1 -tile 4x tmp-avatar-{1..10}-{5..8}.jpg avatar_samples.jpg

rm tmp-avatar.key tmp-avatar.cert tmp-avatar-{1..10}-{5..8}.jpg
