#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="UNZIP.LUA"
R=0

# Inflate test
TEST="$SCRIPT store"
DATA=$(readlink -f $(which $INTERP))

# Store a binary file in a zip
cp $DATA .
DATA=$(basename $DATA)
SRC="$(sha256sum ./$DATA)"
if [ -f test.zip ]; then rm "test.zip"; fi
zip test.zip -Z store "./$DATA"

# Extract and compare
rm "./$DATA"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$DATA)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$DATA" test.zip

# Inflate test
TEST="$SCRIPT inflate"
DATA=$(readlink -f $(which $INTERP))

# Compress a binary file with deflate
cp $DATA .
DATA=$(basename $DATA)
SRC="$(sha256sum ./$DATA)"
if [ -f test.zip ]; then rm "test.zip"; fi
zip test.zip -Z deflate "./$DATA"

# Extract and compare
rm "./$DATA"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$DATA)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$DATA" test.zip

exit $R