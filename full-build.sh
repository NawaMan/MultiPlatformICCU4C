#!/bin/bash

set -e
# set -x
set -o pipefail

DISTDIR=dist
BUILDLOG="$DISTDIR/build.log"


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color



print() {
    echo "$@" | tee -a "$BUILDLOG"
}
print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"

    echo ""           >> "$BUILDLOG"
    echo "=== $1 ===" >> "$BUILDLOG"
    echo ""           >> "$BUILDLOG"
}
print_status() {
    echo -e "\n${BLUE}$1${NC}"

    echo ""   >> "$BUILDLOG"
    echo "$1" >> "$BUILDLOG"
}
exit_with_error() {
    echo -e "${RED}ERROR: $1${NC}"

    echo "ERROR: $1" >> "$BUILDLOG"
    exit 1
}

# Create icu-dist directory if it doesn't exist
mkdir -p $(pwd)/$DISTDIR

touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

# Build the Docker image
docker build . -t icu4c-builder

# Run the container with volume mapping for icu-dist
docker run --rm -v $(pwd)/$DISTDIR:/app/$DISTDIR icu4c-builder:latest

# Done
print_section "Done!"

print_status "✅ ICU build complete. Output in:"
print $DISTDIR

print_status  "Built directories:"
ls -ld "$DISTDIR"/*/    | tee -a "$BUILDLOG"

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip  | tee -a "$BUILDLOG"

print_status "Detail build log can be found at: "
print $BUILDLOG

chmod ugo+rwx $(pwd)/$DISTDIR
