#!/bin/bash
set -e
set -o pipefail



WORKDIR=$(pwd)/build
DISTDIR=$(pwd)/dist
BUILDLOG="$DISTDIR/build.log"

echo "==========================================================================="
echo -e "\033[0;32mDetail build log can be found at: $BUILDLOG\033[0m"
echo "==========================================================================="

mkdir -p  "$WORKDIR"
mkdir -p  "$DISTDIR"
touch     "$BUILDLOG"
echo "" > "$BUILDLOG"

# mac-build.sh does not concern the QUICK_BUILD variable or any build variables from common.source.
# If follows the parameter passed to it: x86_64, arm64, or universal.
source common.source


ARCHS=()
# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --icu-version)
      ICU_VERSION="$2"
      shift 2
      ;;
    x86_64|arm64|universal)
      ARCHS+=("$1")
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo "Usage: $0 [--icu-version <version>] [x86_64 arm64 universal]"
      exit 1
      ;;
  esac
done

# Default to all if none specified
if [[ ${#ARCHS[@]} -eq 0 ]]; then
  ARCHS=("x86_64" "arm64" "universal")
fi

ROOT_DIR="$(pwd)"
ICU_SOURCE="$ROOT_DIR/build/icu/source"
WORKDIR="$ROOT_DIR/build-macos"
DISTDIR="$ROOT_DIR/dist"

mkdir -p "$DISTDIR"
rm -rf "$WORKDIR"

build_arch() {
  ARCH_NAME="$1"
  HOST="$2"
  BUILD_DIR="$WORKDIR/$ARCH_NAME"

  echo "🔧 Building for $ARCH_NAME"

  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  export CC="clang"
  export CXX="clang++"
  export CFLAGS="-arch $ARCH_NAME -O2"
  export CXXFLAGS="-arch $ARCH_NAME -O2"

  "$ICU_SOURCE/configure" \
    --prefix="$BUILD_DIR/install" \
    --host="$HOST" \
    --enable-static \
    --disable-shared \
    --with-data-packaging=static \
    --disable-extras \
    --disable-tests \
    --disable-samples \
    --enable-tools \
    > configure.log 2>&1

  make -j$(sysctl -n hw.logicalcpu) >> build.log 2>&1
  make install >> build.log 2>&1
}

merge_universal() {
  echo "🪄 Merging universal binary..."
  OUTDIR="$WORKDIR/universal"
  mkdir -p "$OUTDIR/lib" "$OUTDIR/include"

  for libfile in "$WORKDIR/x86_64/install/lib"/*.a; do
    base=$(basename "$libfile")
    lipo -create \
      "$WORKDIR/x86_64/install/lib/$base" \
      "$WORKDIR/arm64/install/lib/$base" \
      -output "$OUTDIR/lib/$base"
  done

  cp -r "$WORKDIR/x86_64/install/include" "$OUTDIR/"

  ZIP_NAME="icu4c-${ICU_VERSION}-macos-universal-clang${CLANG_VERSION}.zip"
  cd "$OUTDIR"
  zip -r "$DISTDIR/$ZIP_NAME" . > /dev/null
  echo "✅ Created: dist/$ZIP_NAME"
}

package_single_arch() {
  ARCH_DIR="$WORKDIR/$1/install"
  OUT_NAME="icu4c-${ICU_VERSION}-macos-$1-clang${CLANG_VERSION}.zip"

  cd "$ARCH_DIR"
  zip -r "$DISTDIR/$OUT_NAME" . > /dev/null
  echo "✅ Created: dist/$OUT_NAME"
}

# Main
echo "📦 mac-build.sh - Building ICU $ICU_VERSION"
echo "🔍 ICU source expected in: $ICU_SOURCE"
echo

if [[ ! -d "$ICU_SOURCE" ]]; then
  echo "❌ ICU source directory not found: $ICU_SOURCE"
  echo "Make sure to run ./build.sh --prepare-only to unpack the source."
  exit 1
fi

for ARCH in "${ARCHS[@]}"; do
  case "$ARCH" in
    x86_64)
      build_arch x86_64 x86_64-apple-darwin
      package_single_arch x86_64
      ;;
    arm64)
      build_arch arm64 arm-apple-darwin
      package_single_arch arm64
      ;;
    universal)
      if [[ ! -d "$WORKDIR/x86_64/install" || ! -d "$WORKDIR/arm64/install" ]]; then
        echo "❗ Skipping universal: both x86_64 and arm64 must be built first"
      else
        merge_universal
      fi
      ;;
    *)
      echo "❌ Unknown architecture: $ARCH"
      echo "Supported values: x86_64, arm64, universal"
      exit 1
      ;;
  esac
done
