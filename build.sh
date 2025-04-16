#!/bin/bash

# WARNING! This file is to be used by quick-build.sh (local build) or full-build.sh (docker build).
# Make sure you know what you are doing if you are calling this directly.

# build.sh: Cross-compile ICU4C as static library for multiple platforms

set -e
# set -x
set -o pipefail

if [[ "$1" == "--help" ]]; then
  echo -e "\033[1;33mUsage:\033[0m $0 [options]\n"
  echo "Options:"
  echo "  --quick                      Only build for Linux using Clang 18"
  echo "  --ignore-compiler-version    Skip compiler version checks"
  echo "  --clean                      Run clean.sh before building"
  echo "  --help                       Show this help message"
  exit 0
fi

CLANG_VERSION="18"
ICU_VERSION="77.1"
ICU_MAJ_VER="77"
ENSDK_VERSION="4.0.6"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


PREPARE_ONLY=0
BUILD_TESTS="ON"
ENABLE_COVERAGE="OFF"
CLEAN_BUILD=0
VERBOSE_TESTS=0
IGNORE_COMPILER_VERSION=0
BUILD_CLANG=1
BUILD_MINGW32=1
BUILD_WASM=1
BUILD_LLVMIR=1



WORKDIR=$(pwd)/build
DISTDIR=$(pwd)/dist

BUILDLOG="$DISTDIR/build.log"


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



for arg in "$@"; do
  case "$arg" in
    --ignore-compiler-version)
      IGNORE_COMPILER_VERSION=1 ;;
    --quick)
      BUILD_CLANG=1; BUILD_MINGW32=0; BUILD_WASM=0; BUILD_LLVMIR=0 ;;
    --clean)
      print_section "Cleaning build output"; ./clean.sh ;;
    --prepare-only)
      PREPARE_ONLY=1 ;;
  esac
done



mkdir -p "$WORKDIR" "$DISTDIR"
chmod -R ugo+rwx "$DISTDIR"
cd "$WORKDIR"



ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"



print_section "Prepare ICU"
ICU4C_FILE=icu4c.tgz
if [ ! -f "$ICU4C_FILE" ]; then
  print "📥 Downloading ICU4C..."
  wget -nv -O $ICU4C_FILE "$ICU_URL"
fi

print "📦 Extracting ICU..."
rm -rf icu
mkdir icu
cd icu
tar -xzf ../$ICU4C_FILE --strip-components=1

print "✅ ICU is ready at $WORKDIR/icu"

if [[ "$PREPARE_ONLY" -eq 1 ]]; then
  print "✅ Prepare completed, ICU is ready at $WORKDIR/icu"
  exit 0
fi


ACTUAL_CLANG_VERSION=$(clang --version | grep -o 'clang version [0-9]\+' | awk '{print $3}')
if [[ $BUILD_CLANG -eq 1 && $IGNORE_COMPILER_VERSION -eq 0 ]]; then
  [[ $ACTUAL_CLANG_VERSION != $CLANG_VERSION* ]] && exit_with_error "Clang version $CLANG_VERSION.x required, found $ACTUAL_CLANG_VERSION."
fi
LINUX_CLANG_TARGET_32="linux-x86_32-clang-${ACTUAL_CLANG_VERSION%%.*}"
LINUX_CLANG_TARGET_64="linux-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"



build_wasm_llvm_ir_variant() {
  for BITNESS in 32 64; do
    local TARGET="wasm${BITNESS}"
    local LLVM_IR_DIR="$DISTDIR/llvm-ir-${ACTUAL_CLANG_VERSION%%.*}/$TARGET"
    local LLVM_BC_DIR="$DISTDIR/llvm-bc-${ACTUAL_CLANG_VERSION%%.*}/$TARGET"
    mkdir -p "$LLVM_IR_DIR" "$LLVM_BC_DIR"

    print_section "Generating LLVM IR/BC files for WebAssembly (${TARGET})"

    find "$ICU_SOURCE" -name '*.cpp' \
      ! -path '*/samples/*' \
      ! -path '*/test/*' \
      ! -path '*/perf/*' \
      ! -path '*/tools/*' \
      | while read -r cppfile; do

      relpath=$(realpath --relative-to="$ICU_SOURCE" "$cppfile")
      if grep -q 'LETypes.h' "$cppfile"; then
        print "⚠️  Skipping $relpath (LETypes.h)"
        continue
      fi

      mkdir -p "$LLVM_IR_DIR/$(dirname "$relpath")"
      mkdir -p "$LLVM_BC_DIR/$(dirname "$relpath")"

      macro=""
      case "$cppfile" in
        */common/*)   macro="-DU_COMMON_IMPLEMENTATION" ;; 
        */i18n/*)     macro="-DU_I18N_IMPLEMENTATION" ;; 
        */layoutex/*) macro="-DU_LAYOUTEX_IMPLEMENTATION" ;; 
        */io/*)       macro="-DU_IO_IMPLEMENTATION" ;; 
      esac

      em_target="wasm${BITNESS}-unknown-emscripten"

      em++ -std=c++23 -S -emit-llvm -target $em_target $macro \
        -I"$ICU_SOURCE" -I"$ICU_SOURCE/common" -I"$ICU_SOURCE/i18n" \
        -I"$ICU_SOURCE/layoutex" -I"$ICU_SOURCE/layout" -I"$ICU_SOURCE/io" \
        "$cppfile" \
        -o "$LLVM_IR_DIR/$(dirname "$relpath")/$(basename "$cppfile" .cpp).ll" \
        >> "$BUILDLOG" 2>&1 \
        || exit_with_error "Failed IR: $relpath"

      em++ -std=c++23 -c -emit-llvm -O2 -target $em_target $macro \
        -I"$ICU_SOURCE" -I"$ICU_SOURCE/common" -I"$ICU_SOURCE/i18n" \
        -I"$ICU_SOURCE/layoutex" -I"$ICU_SOURCE/layout" -I"$ICU_SOURCE/io" \
        "$cppfile" \
        -o "$LLVM_BC_DIR/$(dirname "$relpath")/$(basename "$cppfile" .cpp).bc" \
        >> "$BUILDLOG" 2>&1 \
        || exit_with_error "Failed BC: $relpath"
    done
  done
}



build_icu() {
  TARGET="$1"; HOST="$2"; CC="$3"; CXX="$4"; AR="$5"; RANLIB="$6"; EXTRA_FLAGS="$7";  EXTRA_CFLAGS="$8"; EXTRA_CXXFLAGS="$9"
  print_section "Build ICU for $TARGET"

  BUILD_DIR="$WORKDIR/build-$TARGET"
  INSTALL_DIR="$DISTDIR/$TARGET"
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}-$TARGET.zip"

  rm    -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p  "$BUILD_DIR" "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/include"
  cd "$BUILD_DIR"

  ICU_SOURCE="$WORKDIR/icu/source"
  local ENABLE_TOOLS="--disable-tools"
  [[ "$TARGET" == "$LINUX_CLANG_TARGET_32" || "$TARGET" == "$LINUX_CLANG_TARGET_64" ]] \
      && ENABLE_TOOLS="--enable-tools"

  PKG_CONFIG_LIBDIR=                                \
  CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"     \
  CFLAGS="$EXTRA_CFLAGS" CXXFLAGS="$EXTRA_CXXFLAGS" \
  "$ICU_SOURCE/configure"        \
    --prefix="$INSTALL_DIR"      \
    --host="$HOST"               \
    --enable-static              \
    --disable-shared             \
    --with-data-packaging=static \
    --disable-extras             \
    --disable-tests              \
    --disable-samples            \
    $ENABLE_TOOLS                \
    $EXTRA_FLAGS                 \
    >> "$BUILDLOG" 2>&1

  make -j$(nproc)   >> "$BUILDLOG" 2>&1
  make install      >> "$BUILDLOG" 2>&1

  zip -r "$ZIP_FILE" ./  >> "$BUILDLOG" 2>&1
  print_status "✅ Created $ZIP_FILE"
  chmod -R ugo+rwx "$DISTDIR"
}



build_llvm_ir_variant() {
  local BITNESS="$1"
  local CFLAGS=""
  [[ "$BITNESS" == "32" ]] && CFLAGS="-m32"

  local LLVM_IR_DIR="$DISTDIR/llvm-ir-${ACTUAL_CLANG_VERSION%%.*}/$BITNESS/$LINUX_CLANG_TARGET_$BITNESS"
  local LLVM_BC_DIR="$DISTDIR/llvm-bc-${ACTUAL_CLANG_VERSION%%.*}/$BITNESS/$LINUX_CLANG_TARGET_$BITNESS"
  mkdir -p "$LLVM_IR_DIR" "$LLVM_BC_DIR"

  print_section "Generating LLVM IR/BC files for Clang ${ACTUAL_CLANG_VERSION%%.*} ($BITNESS-bit)"

  find "$ICU_SOURCE" -name '*.cpp' \
    ! -path '*/samples/*' \
    ! -path '*/test/*'    \
    ! -path '*/perf/*'    \
    ! -path '*/tools/*'   \
    | while read -r cppfile; do

    relpath=$(realpath --relative-to="$ICU_SOURCE" "$cppfile")
    if grep -q 'LETypes.h' "$cppfile"; then
      print "⚠️  Skipping $relpath (LETypes.h)"
      continue
    fi

    mkdir -p "$LLVM_IR_DIR/$(dirname "$relpath")"
    mkdir -p "$LLVM_BC_DIR/$(dirname "$relpath")"

    macro=""
    case "$cppfile" in
      */common/*)   macro="-DU_COMMON_IMPLEMENTATION"   ;;
      */i18n/*)     macro="-DU_I18N_IMPLEMENTATION"     ;;
      */layoutex/*) macro="-DU_LAYOUTEX_IMPLEMENTATION" ;;
      */io/*)       macro="-DU_IO_IMPLEMENTATION"       ;;
    esac

    clang -std=c++23 -S -emit-llvm $CFLAGS $macro \
      -I"$ICU_SOURCE"          \
      -I"$ICU_SOURCE/common"   \
      -I"$ICU_SOURCE/i18n"     \
      -I"$ICU_SOURCE/layoutex" \
      -I"$ICU_SOURCE/layout"   \
      -I"$ICU_SOURCE/io"       \
      "$cppfile"               \
      -o "$LLVM_IR_DIR/$(dirname "$relpath")/$(basename "$cppfile" .cpp).ll" >> "$BUILDLOG" 2>&1 \
      || exit_with_error "Failed IR: $relpath"

    clang -std=c++23 -c -emit-llvm -O2 $CFLAGS $macro \
      -I"$ICU_SOURCE"          \
      -I"$ICU_SOURCE/common"   \
      -I"$ICU_SOURCE/i18n"     \
      -I"$ICU_SOURCE/layoutex" \
      -I"$ICU_SOURCE/layout"   \
      -I"$ICU_SOURCE/io"       \
      "$cppfile"               \
      -o "$LLVM_BC_DIR/$(dirname "$relpath")/$(basename "$cppfile" .cpp).bc" >> "$BUILDLOG" 2>&1 \
      || exit_with_error "Failed BC: $relpath"
  done

  # Assemble the devkit
  LLVM_KIT_DIR="$DISTDIR/llvm-kit-${ACTUAL_CLANG_VERSION%%.*}-$BITNESS"
  mkdir -p "$LLVM_KIT_DIR/llvm-ir" "$LLVM_KIT_DIR/llvm-bc"
  rsync -a "$LLVM_IR_DIR/" "$LLVM_KIT_DIR/llvm-ir/"
  rsync -a "$LLVM_BC_DIR/" "$LLVM_KIT_DIR/llvm-bc/"
  rsync -a "$DISTDIR/$LINUX_CLANG_TARGET_64/include/" "$LLVM_KIT_DIR/include/"

  # Add helper scripts
  KIT_FILES="$WORKDIR/../artifacts/llvm-devkit"
  if [ -f "$KIT_FILES/build-lib-from-llvm.sh" ]; then
    cp "$KIT_FILES/build-lib-from-llvm.sh" "$LLVM_KIT_DIR/"
  fi
  if [ -f "$KIT_FILES/README.md" ]; then
    cp "$KIT_FILES/README.md" "$LLVM_KIT_DIR/"
  fi

  # Create zip
  ZIP_OUT="$DISTDIR/icu4c-${ICU_VERSION}-llvm-kit-${BITNESS}.zip"
  zip -r "$ZIP_OUT" . >> "$BUILDLOG" 2>&1

  print_status "✅ Created full LLVM kit zip ($BITNESS-bit): $ZIP_OUT"
}



if [[ $BUILD_CLANG -eq 1 ]]; then
  build_icu "$LINUX_CLANG_TARGET_32" "" clang clang++ llvm-ar llvm-ranlib "" "-O2 -m32" "-O2 -m32"
  build_icu "$LINUX_CLANG_TARGET_64" "" clang clang++ llvm-ar llvm-ranlib "" "-O2"      "-O2"

  if [[ "$BUILD_LLVMIR" == "1" ]]; then
    build_llvm_ir_variant 32
    build_llvm_ir_variant 64
  fi
fi

if [[ $BUILD_MINGW32 -eq 1 ]]; then
  print_section "Build ICU for Windows"

  WINDOWS_CLANG_TARGET_64="windows-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"
  WINDOWS_CLANG_TARGET_32="windows-x86-32-clang-${ACTUAL_CLANG_VERSION%%.*}"

  build_icu "$WINDOWS_CLANG_TARGET_64" \
    x86_64-w64-mingw32 \
    "clang --target=x86_64-w64-windows-gnu" \
    "clang++ --target=x86_64-w64-windows-gnu" \
    llvm-ar llvm-ranlib \
    "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64" \
    "-O2" "-O2"

  build_icu "$WINDOWS_CLANG_TARGET_32" \
    i686-w64-mingw32 \
    "clang --target=i686-w64-windows-gnu" \
    "clang++ --target=i686-w64-windows-gnu" \
    llvm-ar llvm-ranlib \
    "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64" \
    "-O2" "-O2"
fi

if [[ $BUILD_WASM -eq 1 ]]; then
  print_section "Build WEB ASM"
  if [ ! -d emsdk ]; then
    git clone https://github.com/emscripten-core/emsdk.git
  fi
  cd emsdk
  EMSDK=$(pwd)
  git checkout $ENSDK_VERSION
  ./emsdk install latest    >> "$BUILDLOG" 2>&1
  ./emsdk activate latest   >> "$BUILDLOG" 2>&1
  cd -

  source "$EMSDK/emsdk_env.sh"
  cp "$WORKDIR/icu/source/config/mh-linux" "$WORKDIR/icu/source/config/mh-unknown"
  build_icu "wasm32" wasm32 emcc em++ emar emranlib "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64"
  build_icu "wasm64" wasm64 emcc em++ emar emranlib "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64"
  build_wasm_llvm_ir_variant
fi

print_status "✅ ICU build is all complete."
