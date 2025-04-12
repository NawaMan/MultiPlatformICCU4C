#!/bin/bash

# icu-cross-build.sh: Cross-compile ICU4C as static library for multiple platforms
# Platforms: linux-x86_64-gcc-13, linux-x86_64-clang-18, windows-x86_64-gcc-13, wasm32 (Emscripten)

set -e

if [[ "$1" == "--help" ]]; then
  echo -e "${YELLOW}Usage:${NC} $0 [options]\n"
  echo "Options:"
  echo "  --quick, --clang-only         Only build for Linux using Clang 18"
  echo "  --ignore-compiler-version     Skip compiler version checks"
  echo "  --clean                       Run clean.sh before building"
  echo "  --help                        Show this help message"
  echo
  echo "By default, this script builds ICU for:"
  echo "  - Linux (GCC 13 and Clang 18)"
  echo "  - Windows (MinGW GCC 13)"
  echo "  - WebAssembly (Emscripten ${ENSDK_VERSION})"
  exit 0
fi

REQUIRED_GCC_VERSION="13"
REQUIRED_CLANG_VERSION="18"
ICU_VERSION="74.2"
ICU_MAJ_VER="74"
ENSDK_VERSION="4.0.6"

# Default configuration
BUILD_TESTS="ON"
ENABLE_COVERAGE="OFF"
CLEAN_BUILD=0
VERBOSE_TESTS=0
IGNORE_COMPILER_VERSION=0
LINUX_ONLY=0

BUILD_CLANG=1
BUILD_GCC=1
BUILD_MINGW32=1
BUILD_WASM32=1

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

# Check command-line arguments
for arg in "$@"; do
  case "$arg" in
    --ignore-compiler-version)
      IGNORE_COMPILER_VERSION=1
      ;;
    --quick|--clang-only)
      BUILD_CLANG=1
      BUILD_GCC=0
      BUILD_MINGW32=0
      BUILD_WASM32=0
      ;;
    --clean)
      print_section "Cleaning build output"
      ./clean.sh
      ;;
  esac
done

# Step: Enforce Clang version check
ACTUAL_CLANG_VERSION=$(clang --version | grep -o 'clang version [0-9]\+' | awk '{print $3}')
if [[ $BUILD_CLANG -eq 1 && $IGNORE_COMPILER_VERSION -eq 0 ]]; then
  if [[ $ACTUAL_CLANG_VERSION != $REQUIRED_CLANG_VERSION* ]]; then
    exit_with_error "Clang version $REQUIRED_CLANG_VERSION.x is required, but found $ACTUAL_CLANG_VERSION. Use --ignore-compiler-version to override."
  fi
fi

ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"

WORKDIR=$(pwd)/icu-build
DISTDIR=$(pwd)/dist

# Construct target names
LINUX_CLANG_TARGET="linux-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"


print_section "Prepare ICU"

mkdir -p "$WORKDIR" "$DISTDIR"
cd "$WORKDIR"

#  Download ICU source
if [ ! -f "icu4c.tgz" ]; then
  echo "Downloading ICU4C..."
  wget -O icu4c.tgz "$ICU_URL"
fi

#  Extract
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
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}-$TARGET.zip"

  rm -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p "$BUILD_DIR"
  mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/include"
  cd "$BUILD_DIR"

  ICU_SOURCE="$WORKDIR/icu/source"

  local ENABLE_TOOLS="--disable-tools"
  if [[ "$TARGET" == "$LINUX_GCC_TARGET" || "$TARGET" == "$LINUX_CLANG_TARGET" ]]; then
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

  print_status "Creating zip archive for $TARGET..."
  (cd "$INSTALL_DIR" && zip -r "$ZIP_FILE" ./)
  print_status "✅ Created $ZIP_FILE"
}

if [[ $BUILD_CLANG -eq 1 ]]; then
  print_section "Build CLANG"
  build_icu "$LINUX_CLANG_TARGET" "" clang clang++ llvm-ar llvm-ranlib
fi

if [[ $BUILD_GCC -eq 1 ]]; then
  print_section "Build GCC"
  ACTUAL_GCC_VERSION=$(gcc -dumpversion)
  LINUX_GCC_TARGET="linux-x86_64-gcc-${ACTUAL_GCC_VERSION%%.*}"
  build_icu "$LINUX_GCC_TARGET" "" gcc g++ ar ranlib
fi

if [[ $BUILD_MINGW32 -eq 1 ]]; then
  print_section "Build MINGW32"
  MINGW_GCC_VERSION=$(x86_64-w64-mingw32-gcc -dumpversion || echo "unknown")
  WINDOWS_TARGET="windows-x86_64-gcc-${MINGW_GCC_VERSION%%.*}"
  build_icu "$WINDOWS_TARGET"  \
    x86_64-w64-mingw32        \
    x86_64-w64-mingw32-gcc    \
    x86_64-w64-mingw32-g++    \
    x86_64-w64-mingw32-ar     \
    x86_64-w64-mingw32-ranlib \
    "--with-cross-build=$WORKDIR/build-$LINUX_GCC_TARGET"
fi

if [[ $BUILD_WASM32 -eq 1 ]]; then
  print_section "Build WEB ASM"

  if [ ! -d emsdk ]; then
    git clone https://github.com/emscripten-core/emsdk.git
  fi

  cd emsdk
  EMSDK=$(pwd)
  git checkout $ENSDK_VERSION
  ./emsdk install latest
  ./emsdk activate latest
  cd -

  source "$EMSDK/emsdk_env.sh"
  cp "$WORKDIR/icu/source/config/mh-linux" "$WORKDIR/icu/source/config/mh-unknown"

  build_icu "wasm32" \
    wasm32 \
    emcc \
    em++ \
    emar \
    emranlib \
    "--with-cross-build=$WORKDIR/build-$LINUX_GCC_TARGET"
fi

chmod -R ugo+rwx "$DISTDIR"
