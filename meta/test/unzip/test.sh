#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="UNZIP.LUA"

# Compress a binary file
cp `which $INTERP` .
SRC="$(sha256sum ./$INTERP)"
if [ -f test.zip ]; then rm "test.zip"; fi
zip test.zip "./$INTERP"

# Extract and compare
rm "./$INTERP"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$INTERP)"
if [ "$SRC" = "$DST" ]; then echo "$SCRIPT": PASS; else echo "$SCRIPT: FAIL"; fi

# Clean up
rm "./$INTERP" test.zip