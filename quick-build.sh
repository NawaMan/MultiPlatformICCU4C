#!/bin/bash

set -e
# set -x
set -o pipefail

DISTDIR=dist
BUILDLOG="$DISTDIR/build.log"

echo "==========================================================================="
echo -e "\033[0;32mDetail build log can be found at: $BUILDLOG\033[0m"
echo "==========================================================================="

rm -Rf "$DISTDIR"

mkdir -p  "$DISTDIR"
touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

QUICK_BUILD=true
VERBOSE=false
source common.source
VERBOSE=true


if [[ $MACOSX86 == true ]]; then
  print_section "Quick macOS (x86_64) build"
  # mac-build.sh does not concern the QUICK_BUILD variable.
  ./mac-build.sh x86_64
  exit 0
fi
if [[ $MACOSARM64 == true ]]; then
  print_section "Quick macOS (arm64) build"
  # mac-build.sh does not concern the QUICK_BUILD variable.
  ./mac-build.sh arm64
  exit 0
fi
if [[ $MACOSX86 == false && $MACOSARM64 == false ]]; then
  print_section "Quick build"
  ./build.sh --quick
  exit 0
fi



print_section "Done!"
print_status "✅ ICU build complete. Output in:"
print $DISTDIR

print_status  "Built directories:"
ls -ld "$DISTDIR"/*/    | tee -a "$BUILDLOG"

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip  | tee -a "$BUILDLOG"
