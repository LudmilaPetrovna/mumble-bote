#!/bin/bash

ddate
file deps_test.sh
for q in {jpg,gif,png,webp};do convert -size 100x500 plasma: test.$q;done
identify test.*
curl --version
curl_chrome110 --version
