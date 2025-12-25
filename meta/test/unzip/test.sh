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

# Inflate uncompressed
TEST="$SCRIPT inflate uncompressed"
DATA=$(readlink -f $(which $INTERP))

# Compress a binary file with deflate uncompressed generator
cp $DATA .
DATA=$(basename $DATA)
SRC="$(sha256sum ./$DATA)"
if [ -f test.zip ]; then rm "test.zip"; fi
cat "./$DATA" | ./genzip1.py "$DATA" > "test.zip"

# Extract and compare
rm "./$DATA"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$DATA)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$DATA" test.zip

# TODO: This test fails but only on Ubuntu. Is 7z broken in that distribution?
# Inflate64 test
TEST="$SCRIPT inflate64"
DATA=$(readlink -f $(which $INTERP))

# Compress a binary file with deflate64
cp $DATA .
DATA=$(basename $DATA)
SRC="$(sha256sum ./$DATA)"
if [ -f test.zip ]; then rm "test.zip"; fi
7z a -tzip -m0=deflate64 test.zip "./$DATA"

# Extract and compare
rm "./$DATA"
$INTERP $SCRIPT test.zip
DST="$(sha256sum ./$DATA)"
if [ "$SRC" = "$DST" ]; then echo "$TEST": PASS; else echo "$TEST: FAIL"; R=$((R+1)); fi
rm "./$DATA" test.zip

exit $R
