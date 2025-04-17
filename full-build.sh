#!/bin/bash

set -e
# set -x
set -o pipefail



WORKDIR=$(pwd)/build
DISTDIR=$(pwd)/dist
BUILDLOG="$DISTDIR/build.log"

mkdir -p "$WORKDIR"
mkdir -p  "$DISTDIR"
chown -R $(id -u):$(id -gn) $DISTDIR
chmod g+s $DISTDIR
setfacl -d -m g:$(id -gn):rwx $DISTDIR
setfacl    -m g:$(id -gn):rwx $DISTDIR

touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

source common.source

print "WORKDIR: $WORKDIR"
print "DISTDIR: $DISTDIR"
print "BUILDLOG: $BUILDLOG"
print "CLANG_VERSION: $CLANG_VERSION"
print "ICU_VERSION:   $ICU_VERSION"
print "ENSDK_VERSION: $ENSDK_VERSION"
print ""



check_versions_match_changelog



# Build the Docker image
docker build . \
  --build-arg CLANG_VERSION=$CLANG_VERSION \
  --build-arg ICU_VERSION=$ICU_VERSION     \
  --build-arg ENSDK_VERSION=$ENSDK_VERSION \
  -t icu4c-builder



# Run the container with volume mapping for dist
docker run --rm -v "$DISTDIR:/app/dist" icu4c-builder:latest



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
