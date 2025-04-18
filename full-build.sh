#!/bin/bash

# full-build.sh: Build ICU4C for all supported platforms using Docker
#
# Usage:
#   ./full-build.sh [--dry-run]
#
# Options:
#   --dry-run   Show what would be built, but do not execute any build commands (passed through to build.sh)


set -e
# set -x
set -o pipefail

if [[ "$1" == "--help" ]]; then
  echo -e "\033[1;33mUsage:\033[0m $0 [--dry-run]"
  echo "Options:"
  echo "  --dry-run   Show what would be built, but do not execute any build commands (passed through to build.sh)"
  echo "  --help      Show this help message"
  exit 0
fi



WORKDIR=$(pwd)/build
DISTDIR=$(pwd)/dist
BUILDLOG="$DISTDIR/build.log"

echo "==========================================================================="
echo -e "\033[0;32mDetail build log can be found at: $BUILDLOG\033[0m"
echo "==========================================================================="

mkdir -p "$WORKDIR"
mkdir -p  "$DISTDIR"
chown -R $(id -u):$(id -gn) $DISTDIR
chmod g+s $DISTDIR
setfacl -d -m g:$(id -gn):rwx $DISTDIR
setfacl    -m g:$(id -gn):rwx $DISTDIR

touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

QUICK_BUILD=false
source common.source

print "CLANG_VERSION: $CLANG_VERSION"
print "ICU_VERSION:   $ICU_VERSION"
print "ENSDK_VERSION: $ENSDK_VERSION"
print "WORKDIR:  $WORKDIR"
print "DISTDIR:  $DISTDIR"
print "BUILDLOG: $BUILDLOG"
print ""


print_section "Check versions match changelog"
check_versions_match_changelog



print_section "Build the Docker image"
docker build . \
  --build-arg CLANG_VERSION=$CLANG_VERSION \
  --build-arg ICU_VERSION=$ICU_VERSION     \
  --build-arg ENSDK_VERSION=$ENSDK_VERSION \
  -t icu4c-builder



print_section "Run the container with volume mapping for dist"
DOCKER_ARGS=""
if [[ "$1" == "--dry-run" ]]; then
  DOCKER_ARGS="--dry-run"
fi

docker run --rm -v "$DISTDIR:/app/dist" icu4c-builder:latest $DOCKER_ARGS



print_section "Done!"

print_status "✅ ICU build complete. Output in:"
print $DISTDIR

print_status  "Built directories:"
ls -ld "$DISTDIR"/*/    | tee -a "$BUILDLOG"

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip  | tee -a "$BUILDLOG"

print_status "Detail build log can be found at: "
print $BUILDLOG
