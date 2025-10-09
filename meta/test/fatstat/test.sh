#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
TEST="FATSTAT"
SCRIPT="FATSTAT.LUA"

dd if=/dev/zero of=test.ima bs=512 count=320 status=none
mformat -i test.ima -f 160
CHASH=$(sha256sum test.ima)
# Insert junk data to wipe
dd if=/dev/random of=test.ima bs=512 count=2 seek=300 status=none
RHASH=$(sha256sum test.ima)
if [ "$CHASH" = "$RHASH" ]; then die; fi
$INTERP $SCRIPT -z test.ima
ZHASH=$(sha256sum test.ima)
rm test.ima
if [ "$CHASH" = "$ZHASH" ]; then echo "$TEST: PASS"; else echo "$TEST: FAIL"; exit 1; fi