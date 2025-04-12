#!/bin/bash

# icu-cross-build.sh: Cross-compile ICU4C as static library for multiple platforms
# Platforms: linux-x86_64-gcc-13, windows-x86_64-gcc-13, wasm32 (Emscripten)

set -e

REQUIRED_GCC_VERSION="13"
ICU_VERSION="74.2"
ICU_MAJ_VER="74"
ENSDK_VERSION="4.0.6"

# Default configuration
BUILD_TESTS="ON"
ENABLE_COVERAGE="OFF"
CLEAN_BUILD=0
VERBOSE_TESTS=0
IGNORE_COMPILER_VERSION=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section header
print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Function to print status
print_status() {
    echo -e "${BLUE}$1${NC}"
}

# Function to print error and exit
exit_with_error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Check for --ignore-compiler-version flag
for arg in "$@"; do
  if [[ "$arg" == "--ignore-compiler-version" ]]; then
    IGNORE_COMPILER_VERSION=1
  fi
done

# Step: Enforce GCC version check (for native Linux build)
ACTUAL_GCC_VERSION=$(gcc -dumpversion)
if [[ $IGNORE_COMPILER_VERSION -eq 0 ]]; then
  if [[ $ACTUAL_GCC_VERSION != $REQUIRED_GCC_VERSION* ]]; then
    exit_with_error "GCC version $REQUIRED_GCC_VERSION.x is required, but found $ACTUAL_GCC_VERSION. Use --ignore-compiler-version to override."
  fi
fi

# Get MinGW GCC version
MINGW_GCC_VERSION=$(x86_64-w64-mingw32-gcc -dumpversion || echo "unknown")

# Construct target names
LINUX_TARGET="linux-x86_64-gcc-${ACTUAL_GCC_VERSION%%.*}"
WINDOWS_TARGET="windows-x86_64-gcc-${MINGW_GCC_VERSION%%.*}"

ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"

WORKDIR=$(pwd)/icu-build
DISTDIR=$(pwd)/icu-dist

print_section "Download Emscripten"

if [ ! -d emsdk ]; then
  git clone https://github.com/emscripten-core/emsdk.git
fi

cd emsdk
EMSDK=$(pwd)
git checkout $ENSDK_VERSION
./emsdk install latest
./emsdk activate latest
cd -

mkdir -p "$WORKDIR" "$DISTDIR"
cd "$WORKDIR"

print_section "Download ICU"

# Step 1: Download ICU source
if [ ! -f "icu4c.tgz" ]; then
  echo "Downloading ICU4C..."
  wget -O icu4c.tgz "$ICU_URL"
fi

# Step 2: Extract
rm -rf icu
mkdir icu
cd icu

# Some releases require extracting twice
tar -xzf ../icu4c.tgz --strip-components=1

# Function: build for a given target
build_icu() {
  TARGET="$1"
  HOST="$2"
  CC="$3"
  CXX="$4"
  AR="$5"
  RANLIB="$6"
  EXTRA_FLAGS="$7"

  print_section "Build ICU for $TARGET"

  BUILD_DIR="$WORKDIR/build-$TARGET"
  INSTALL_DIR="$DISTDIR/$TARGET"

  rm -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p "$BUILD_DIR"
  mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/include"
  cd "$BUILD_DIR"

  ICU_SOURCE="$WORKDIR/icu/source"

  local ENABLE_TOOLS="--disable-tools"
  if [ "$TARGET" = "$LINUX_TARGET" ]; then
    ENABLE_TOOLS="--enable-tools"
  fi

  PKG_CONFIG_LIBDIR= \
  CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
  "$ICU_SOURCE/configure" \
    --prefix="$INSTALL_DIR" \
    --host="$HOST" \
    --enable-static \
    --disable-shared \
    --with-data-packaging=static \
    --disable-extras \
    --disable-tests \
    --disable-samples \
    $ENABLE_TOOLS \
    $EXTRA_FLAGS

  make -j$(nproc)
  make install
}

# Step 3: Build targets

# Native Linux x86_64
build_icu "$LINUX_TARGET" "" gcc g++ ar ranlib

# Windows x86_64 (MinGW)
build_icu "$WINDOWS_TARGET"  \
  x86_64-w64-mingw32        \
  x86_64-w64-mingw32-gcc    \
  x86_64-w64-mingw32-g++    \
  x86_64-w64-mingw32-ar     \
  x86_64-w64-mingw32-ranlib \
  "--with-cross-build=$WORKDIR/build-$LINUX_TARGET"

# WebAssembly (Emscripten)
source "$EMSDK/emsdk_env.sh"

# Force platform detection by copying mh-linux to mh-unknown
cp "$WORKDIR/icu/source/config/mh-linux" "$WORKDIR/icu/source/config/mh-unknown"

build_icu "wasm32" \
  wasm32 \
  emcc \
  em++ \
  emar \
  emranlib \
  "--with-cross-build=$WORKDIR/build-$LINUX_TARGET"

# Done
echo ""
print_status "✅ ICU build complete. Output in: $DISTDIR"
ls -l "$DISTDIR"
