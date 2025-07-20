#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
TEST="FATSTAT"
SCRIPT="FATSTAT.LUA"

mformat -i test.ima -C -f 160
CHASH=$(sha256sum test.ima)
# Insert junk data to wipe
dd if=/dev/random of=test.ima bs=512 count=2 seek=300 status=none
RHASH=$(sha256sum test.ima)
if [ "$CHASH" = "$RHASH" ]; then die; fi
$INTERP $SCRIPT -z test.ima
ZHASH=$(sha256sum test.ima)
rm test.ima
if [ "$CHASH" = "$ZHASH" ]; then echo "$TEST: PASS"; else echo "$TEST: FAIL"; fi