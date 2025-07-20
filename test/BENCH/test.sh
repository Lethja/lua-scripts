#!/usr/bin/env sh
set -e
INTERP=${INTERP:-lua}
SCRIPT="BENCH.LUA"

cd ../../core
echo | $INTERP $SCRIPT 1980
cd ../bench
echo | $INTERP $SCRIPT 1980
echo "BENCH: PASS"