#!/bin/bash

set -e
# set -x
set -o pipefail

DISTDIR=dist
BUILDLOG="$DISTDIR/build.log"

echo "==========================================================================="
echo "\033[0;32m Detail build log can be found at: $BUILDLOG\033[0m"
echo "==========================================================================="

rm -Rf "$DISTDIR"

mkdir -p  "$DISTDIR"
touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

source common.source



print_section "Quick build"
./build.sh --quick



print_section "Done!"
print_status "✅ ICU build complete. Output in:"
print $DISTDIR

print_status  "Built directories:"
ls -ld "$DISTDIR"/*/    | tee -a "$BUILDLOG"

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip  | tee -a "$BUILDLOG"
