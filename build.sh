#!/bin/bash

# icu-cross-build.sh: Cross-compile ICU4C as static library for multiple platforms
# Platforms: linux-x86_64-gcc-13, linux-x86_64-clang-18, windows-x86_64-gcc-13, wasm32 (Emscripten)

set -e



# Versions
REQUIRED_GCC_VERSION="13"
REQUIRED_CLANG_VERSION="18"
ICU_VERSION="77.1"
ICU_MAJ_VER="77"
ENSDK_VERSION="4.0.6"



# Color output.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color



print() {
    echo "$@"
}

print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

print_status() {
    echo -e "${BLUE}$1${NC}"
}

exit_with_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    exit 1
}



# Help
if [[ "$1" == "--help" ]]; then
  print -e "${YELLOW}Usage:${NC} $0 [options]\n"
  print "Options:"
  print "  --quick                      Only build for Linux using Clang 18"
  print "  --ignore-compiler-version    Skip compiler version checks"
  print "  --clean                      Run clean.sh before building"
  print "  --help                       Show this help message"
  exit 0
fi



# Default configuration
BUILD_TESTS="ON"
ENABLE_COVERAGE="OFF"
CLEAN_BUILD=0
VERBOSE_TESTS=0
IGNORE_COMPILER_VERSION=0

BUILD_CLANG=1
BUILD_GCC=1
BUILD_MINGW32=1
BUILD_WASM32=1
BUILD_LLVMIR=1

for arg in "$@"; do
  case "$arg" in
    --ignore-compiler-version) IGNORE_COMPILER_VERSION=1 ;;
    --quick)
      BUILD_CLANG=1
      BUILD_GCC=0
      BUILD_MINGW32=0
      BUILD_WASM32=0
      BUILD_LLVMIR=0 ;;
    --clean)
      print_section "Cleaning build output"
      ./clean.sh ;;
  esac
done



ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"

WORKDIR=$(pwd)/build
DISTDIR=$(pwd)/dist

mkdir -p "$WORKDIR" "$DISTDIR"
chmod -R ugo+rwx "$DISTDIR"
cd "$WORKDIR"



print_section "Prepare ICU"
ICU4C_FILE=icu4c.tgz

if [ ! -f "$ICU4C_FILE" ]; then
  print "Downloading ICU4C..."
  wget -O $ICU4C_FILE "$ICU_URL"
fi

rm -rf icu
mkdir icu
cd icu
tar -xzf ../$ICU4C_FILE --strip-components=1



ACTUAL_CLANG_VERSION=$(clang --version | grep -o 'clang version [0-9]\+' | awk '{print $3}')
if [[ $BUILD_CLANG -eq 1 && $IGNORE_COMPILER_VERSION -eq 0 ]]; then
  if [[ $ACTUAL_CLANG_VERSION != $REQUIRED_CLANG_VERSION* ]]; then
    exit_with_error "Clang version $REQUIRED_CLANG_VERSION.x is required, but found $ACTUAL_CLANG_VERSION. Use --ignore-compiler-version to override."
  fi
fi
LINUX_CLANG_TARGET="linux-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"



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
  if [[ "$TARGET" == "$LINUX_CLANG_TARGET" || "$TARGET" == "$LINUX_GCC_TARGET" ]]; then
    ENABLE_TOOLS="--enable-tools"
  fi

  EXTRA_CFLAGS=""
  EXTRA_CXXFLAGS=""
  if [[ "$CC" == "clang" ]]; then
    EXTRA_CFLAGS="-O2"
    EXTRA_CXXFLAGS="-O2"
  fi

  PKG_CONFIG_LIBDIR= \
  CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
  CFLAGS="$EXTRA_CFLAGS" CXXFLAGS="$EXTRA_CXXFLAGS" \
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

  chmod -R ugo+rwx "$DISTDIR"

  # ========== Emit LLVM IR (.ll) if Clang ==========
  if [[ "$CC" == "clang" && "$BUILD_LLVMIR" == "1" ]]; then
    print_section "Generating LLVM IR (.ll) files for $TARGET"

    LLVM_IR_DIR="$DISTDIR/llvm-ir-${ACTUAL_CLANG_VERSION%%.*}/$TARGET"
    mkdir -p "$LLVM_IR_DIR"

    find "$ICU_SOURCE"        \
          -name '*.cpp'       \
        ! -path '*/samples/*' \
        ! -path '*/test/*'    \
        ! -path '*/perf/*'    \
        ! -path '*/tools/*'   \
        | while read -r cppfile; do
      relpath=$(realpath --relative-to="$ICU_SOURCE" "$cppfile")

      # LETypes.h was removed since version 64.
      #   but some example/test files are still referening to it.
      # So we work around by skip any files that use it.
      # It may be a problem later, but let's go with this for now.
      if grep -q 'LETypes.h' "$cppfile"; then
        print "⚠️  Skipping file due to reference to removed LE layout: $relpath"
        continue
      fi

      outdir="$LLVM_IR_DIR/$(dirname "$relpath")"
      mkdir -p "$outdir"

      cpp_macro=""
      case "$cppfile" in
        */common/*)   cpp_macro="-DU_COMMON_IMPLEMENTATION"   ;;
        */i18n/*)     cpp_macro="-DU_I18N_IMPLEMENTATION"     ;;
        */layoutex/*) cpp_macro="-DU_LAYOUTEX_IMPLEMENTATION" ;;
        */io/*)       cpp_macro="-DU_IO_IMPLEMENTATION"       ;;
      esac

      clang -std=c++23 -S -emit-llvm \
        $cpp_macro                   \
        -I"$ICU_SOURCE"              \
        -I"$ICU_SOURCE/common"       \
        -I"$ICU_SOURCE/i18n"         \
        -I"$ICU_SOURCE/layoutex"     \
        -I"$ICU_SOURCE/layout"       \
        -I"$ICU_SOURCE/io"           \
        "$cppfile"                   \
        -o "$outdir/$(basename "$cppfile" .cpp).ll" || {
          exit_with_error "Failed to compile: $relpath"
          chmod -R ugo+rwx "$DISTDIR"
          exit 1
      }

      chmod -R ugo+rwx "$DISTDIR"
    done

    print_status "✅ LLVM IR files saved to: $LLVM_IR_DIR"

    LLVM_BASE_DIR="$WORKDIR/llvm-devkit"
    mkdir -p "$LLVM_BASE_DIR/llvm-ir"

    KIT_FILES="$WORKDIR/../artifacts/llvm-devkit"
    if [ ! -f "$KIT_FILES/build-lib-from-llvm.sh" ]; then
      print "⚠️ Missing kit artifacts (e.g. build-lib-from-llvm.sh)"
    fi

    rsync -a --exclude='.DS_Store' "$LLVM_IR_DIR/" "$LLVM_BASE_DIR/llvm-ir/"
    rsync -a "$DISTDIR/$LINUX_CLANG_TARGET/include/" "$LLVM_BASE_DIR/include/"
    rsync -a "$KIT_FILES/" "$LLVM_BASE_DIR/"

    # Create zip archive of LLVM IR files
    print_status "Creating LLVM IR zip archive..."
    LLVM_IR_KIT_ZIP="$DISTDIR/icu4c-${ICU_VERSION}-llvm-ir-kit.zip"
    rm -f "$LLVM_IR_KIT_ZIP"
    zip -r "$DISTDIR/icu4c-${ICU_VERSION}-llvm-ir-kit.zip" -j "$LLVM_BASE_DIR"

    print_status "✅ Created $LLVM_IR_ZIP"
  fi
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
  build_icu "$WINDOWS_TARGET" \
    x86_64-w64-mingw32 \
    x86_64-w64-mingw32-gcc \
    x86_64-w64-mingw32-g++ \
    x86_64-w64-mingw32-ar \
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

