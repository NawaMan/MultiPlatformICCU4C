#!/bin/bash

set -e
# set -x
set -o pipefail

DISTDIR=dist
BUILDLOG="$DISTDIR/build.log"

rm -Rf "$DISTDIR"

mkdir -p  "$DISTDIR"
touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

source common.source

print "CLANG_VERSION: $CLANG_VERSION"
print "ICU_VERSION:   $ICU_VERSION"
print "ENSDK_VERSION: $ENSDK_VERSION"
print ""


# Build
./build.sh --quick


# Done
print_section "Done!"

print_status "✅ ICU build complete. Output in:"
print $DISTDIR

print_status  "Built directories:"
ls -ld "$DISTDIR"/*/    | tee -a "$BUILDLOG"

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip  | tee -a "$BUILDLOG"
