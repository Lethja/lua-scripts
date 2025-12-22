#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="UNZIP.LUA"
R=0

# Inflate test
TEST="$SCRIPT store"

# Store a binary file in a zip
cp `which $INTERP` .
SRC="$(sha256sum ./$INTERP)"
if [ -f test.zip ]; then rm "test.zip"; fi
zip test.zip -Z store "./$INTERP"

# Extract and compare
rm "./$INTERP"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$INTERP)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$INTERP" test.zip

# Inflate test
TEST="$SCRIPT inflate"

# Compress a binary file with deflate
cp `which $INTERP` .
SRC="$(sha256sum ./$INTERP)"
if [ -f test.zip ]; then rm "test.zip"; fi
zip test.zip -Z deflate "./$INTERP"

# Extract and compare
rm "./$INTERP"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$INTERP)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$INTERP" test.zip

exit $R