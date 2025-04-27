#!/bin/bash

# WARNING! This file is to be used by quick-build.sh (local build) or full-build.sh (docker build).
# Make sure you know what you are doing if you are calling this directly.

# build.sh: Cross-compile ICU4C as static library for multiple platforms

set -e
set -x
set -o pipefail


if [[ "$1" == "--help" ]]; then
  echo -e "\033[1;33mUsage:\033[0m $0 [options]\n"
  echo "Options:"
  echo "  --quick                      Only build for Linux using Clang"
  echo "  --ignore-compiler-version    Skip compiler version checks"
  echo "  --dry-run                    Show what would be built, but do not execute any build commands"
  echo "  --help                       Show this help message"
  exit 0
fi



PREPARE_ONLY=0
IGNORE_COMPILER_VERSION=0
DRY_RUN=false

QUICK_BUILD=false
UNAME_S=""
UNAME_M=""
for arg in "$@"; do
  case "$arg" in
    --ignore-compiler-version) IGNORE_COMPILER_VERSION=1 ;;
    --quick)                   QUICK_BUILD=true          ;;
    --prepare-only)            PREPARE_ONLY=1            ;;
    --dry-run)                 DRY_RUN=true              ;;
  esac
done


# Disallow quick build on non-Linux
UNAME_S=$(uname -s)
if [[ "$QUICK_BUILD" == "true" && "$UNAME_S" != "Linux" ]]; then
  echo -e "\033[1;31mERROR: quick build (--quick) is only supported on Linux.\033[0m"
  exit 1
fi

WORKDIR=${WORKDIR:-$(pwd)/build}
DISTDIR=${DISTDIR:-$(pwd)/dist}
BUILDLOG="$DISTDIR/build.log"
source common-source.sh

trap 'echo "❌ Error occurred at line $LINENO"; cat dist/64/build.log; exit 1' ERR

common-init "$@"



print_section "Build starts -- configurations"
print "CLANG_VERSION: $CLANG_VERSION"
print "ICU_VERSION:   $ICU_VERSION"
print "ENSDK_VERSION: $ENSDK_VERSION"
print "WORKDIR: $WORKDIR"
print "DISTDIR: $DISTDIR"
print "BUILDLOG: $BUILDLOG"
print ""



print_section "Prepare working directory"
mkdir -p "$WORKDIR"
cd "$WORKDIR"



print_section "Prepare ICU source"
ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"
ICU4C_FILE=icu4c.tgz
if [ ! -f "$ICU4C_FILE" ]; then
  print "📥 Downloading ICU4C..."
  curl -L -o $ICU4C_FILE "$ICU_URL"
  print ""
fi

print "📦 Extracting ICU..."
rm -rf icu
mkdir icu
cd icu
tar -xzf ../$ICU4C_FILE --strip-components=1
print ""

print "✅ ICU is ready at $WORKDIR/icu"

if [[ "$PREPARE_ONLY" -eq 1 ]]; then
  print "✅ Prepare completed, ICU is ready at $WORKDIR/icu"
  print ""
  exit 0
fi



print_section "Check compiler version"
ACTUAL_CLANG_VERSION=$(clang --version | grep -o 'clang version [0-9]\+' | awk '{print $3}')
if [[ $BUILD_CLANG == "true" && $IGNORE_COMPILER_VERSION -eq 0 ]]; then
  if [[ "${ACTUAL_CLANG_VERSION%%.*}" != "$CLANG_VERSION" ]]; then
    exit_with_error "Clang version $CLANG_VERSION.x required, found $ACTUAL_CLANG_VERSION."
  fi
fi

LINUX_CLANG_TARGET_32="linux-x86_32-clang-${ACTUAL_CLANG_VERSION%%.*}"
LINUX_CLANG_TARGET_64="linux-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"

print "✅ Compiler version checked"
print ""



build_icu() {
  TARGET="$1"; HOST="$2"; CC="$3"; CXX="$4"; AR="$5"; RANLIB="$6"; EXTRA_FLAGS="$7";  EXTRA_CFLAGS="$8"; EXTRA_CXXFLAGS="$9"
  print_section "Build ICU for $TARGET"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would build ICU for: TARGET=$TARGET HOST=$HOST CC=$CC CXX=$CXX AR=$AR RANLIB=$RANLIB EXTRA_FLAGS=[$EXTRA_FLAGS] EXTRA_CFLAGS=[$EXTRA_CFLAGS] EXTRA_CXXFLAGS=[$EXTRA_CXXFLAGS]"
    return 0
  fi

  BUILD_DIR="$WORKDIR/build-$TARGET"
  INSTALL_DIR="$DISTDIR/$TARGET"
  # Determine toolchain tag for zip file
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
  "$ICU_SOURCE/configure"         \
    --prefix="$INSTALL_DIR"       \
    --host="$HOST"                \
    --enable-static               \
    --disable-shared              \
    --with-data-packaging=archive \
    --disable-extras              \
    --disable-tests               \
    --disable-samples             \
    $ENABLE_TOOLS                 \
    $EXTRA_FLAGS                  \
    >> "$BUILDLOG" 2>&1

  make -j$(nproc)   >> "$BUILDLOG" 2>&1
  make install      >> "$BUILDLOG" 2>&1

  # Copy ICU headers to the install directory
  print "📋 Copying ICU headers to package..."
  mkdir -p "$INSTALL_DIR/include/unicode"
  
  # Copy headers directly from source directories
  for module in common i18n io layout layoutex; do
    if [ -d "$WORKDIR/icu/source/$module" ]; then
      print "  - Copying $module headers"
      find "$WORKDIR/icu/source/$module" -name "*.h" -exec cp {} "$INSTALL_DIR/include/unicode/" \;
    fi
  done
  
  # Check if headers were copied successfully
  header_count=$(find "$INSTALL_DIR/include/unicode" -name "*.h" | wc -l)
  print "  - Copied $header_count header files"

  # Verify and handle the ICU data file
  print "📦 Verifying ICU data file..."
  
  # Check for the data file in various possible locations
  ICU_DATA_FILE=""
  
  # Check in the standard location first
  STANDARD_DATA_PATH="$INSTALL_DIR/share/icu/$ICU_VERSION/icudt${ICU_VERSION%%.*}l.dat"
  if [[ -f "$STANDARD_DATA_PATH" ]]; then
    ICU_DATA_FILE="$STANDARD_DATA_PATH"
    print "  ✅ Found ICU data file at standard location: $ICU_DATA_FILE"
  else
    # Try to find it in the build directory
    BUILD_DATA_FILE=$(find "$BUILD_DIR" -name "*.dat" | head -n 1)
    if [[ -n "$BUILD_DATA_FILE" ]]; then
      # Create the share directory structure
      mkdir -p "$INSTALL_DIR/share/icu/$ICU_VERSION"
      # Copy the data file to the standard location
      cp "$BUILD_DATA_FILE" "$STANDARD_DATA_PATH"
      ICU_DATA_FILE="$STANDARD_DATA_PATH"
      print "  ✅ Copied ICU data file from build directory to: $ICU_DATA_FILE"
    else
      print "  ⚠️ No ICU data file found! The package may not work correctly."
    fi
  fi

  # If we found a data file, check its size
  if [[ -n "$ICU_DATA_FILE" ]]; then
    DATA_SIZE=$(du -h "$ICU_DATA_FILE" | cut -f1)
    print "  - Data file size: $DATA_SIZE"
  fi

  # Create the zip file from the install directory
  cd "$INSTALL_DIR"
  zip -r "$ZIP_FILE" ./  >> "$BUILDLOG" 2>&1
  print "✅ Created $ZIP_FILE"
  chmod -R ugo+rwx "$DISTDIR"
}

build_wasm_llvm_ir_variant() {
  local BITNESS="$1"
  if [[ "$BITNESS" != "32" && "$BITNESS" != "64" ]]; then
    echo "Usage: build_wasm_llvm_ir_variant <32|64>" >&2
    exit 1
  fi
  local TARGET="wasm${BITNESS}"
  local LLVM_IR_DIR="$DISTDIR/llvm-ir-${ACTUAL_CLANG_VERSION%%.*}/$TARGET"
  local LLVM_BC_DIR="$DISTDIR/llvm-bc-${ACTUAL_CLANG_VERSION%%.*}/$TARGET"
  mkdir -p "$LLVM_IR_DIR" "$LLVM_BC_DIR"

  print_section "Generating LLVM IR/BC files for WebAssembly (${TARGET})"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would generate LLVM IR/BC for WebAssembly: BITNESS=$BITNESS TARGET=$TARGET (Clang ${ACTUAL_CLANG_VERSION%%.*})"
    return 0
  fi

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
}

build_llvm_ir_variant() {
  local BITNESS="$1"
  local CFLAGS=""
  [[ "$BITNESS" == "32" ]] && CFLAGS="-m32"

  local LLVM_IR_DIR="$DISTDIR/llvm-ir-${ACTUAL_CLANG_VERSION%%.*}/$BITNESS/$LINUX_CLANG_TARGET_$BITNESS"
  local LLVM_BC_DIR="$DISTDIR/llvm-bc-${ACTUAL_CLANG_VERSION%%.*}/$BITNESS/$LINUX_CLANG_TARGET_$BITNESS"
  mkdir -p "$LLVM_IR_DIR" "$LLVM_BC_DIR"

  print_section "Generating LLVM IR/BC files for Clang ${ACTUAL_CLANG_VERSION%%.*} ($BITNESS-bit)"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would generate LLVM IR/BC for Linux: BITNESS=$BITNESS TARGET=$LINUX_CLANG_TARGET_$BITNESS (Clang ${ACTUAL_CLANG_VERSION%%.*})"
    return 0
  fi

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
  if [[ "$BITNESS" == "32" ]]; then
    LINUX_CLANG_TARGET="$LINUX_CLANG_TARGET_32"
  elif [[ "$BITNESS" == "64" ]]; then
    LINUX_CLANG_TARGET="$LINUX_CLANG_TARGET_64"
  fi
  
  mkdir -p "$LLVM_KIT_DIR/llvm-ir" "$LLVM_KIT_DIR/llvm-bc"
  rsync -a "$LLVM_IR_DIR/" "$LLVM_KIT_DIR/llvm-ir/"
  rsync -a "$LLVM_BC_DIR/" "$LLVM_KIT_DIR/llvm-bc/"
  rsync -a "$DISTDIR/$LINUX_CLANG_TARGET/include/" "$LLVM_KIT_DIR/include/"

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


show-build-matrix


if [[ "$LINUX_32" == true || "$LINUX_64" == true ]]; then
  # Linux builds
  if [[ "$LINUX_32" == true ]]; then
    build_icu "$LINUX_CLANG_TARGET_32" "" clang clang++ llvm-ar llvm-ranlib "" "-O2 -m32" "-O2 -m32"
    if [[ "$BUILD_LLVMIR" == true && "$LLVMIR32" == true ]]; then
      build_llvm_ir_variant 32
    fi
  fi
  if [[ "$LINUX_64" == true ]]; then
    build_icu "$LINUX_CLANG_TARGET_64" "" clang clang++ llvm-ar llvm-ranlib "" "-O2"      "-O2"
    if [[ "$BUILD_LLVMIR" == true && "$LLVMIR64" == true ]]; then
      build_llvm_ir_variant 64
    fi
  fi
fi

if [[ "$BUILD_WINDOWS" == true ]]; then
  print_section "Build ICU for Windows"

  WINDOWS_CLANG_TARGET_64="windows-x86_64-clang-${ACTUAL_CLANG_VERSION%%.*}"
  WINDOWS_CLANG_TARGET_32="windows-x86-32-clang-${ACTUAL_CLANG_VERSION%%.*}"

  if [[ "$WINDOWS_32" == true ]]; then
    build_icu "$WINDOWS_CLANG_TARGET_32" \
      i686-w64-mingw32 \
      "clang --target=i686-w64-windows-gnu" \
      "clang++ --target=i686-w64-windows-gnu" \
      llvm-ar llvm-ranlib \
      "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_32" \
      "-O2" "-O2"
  fi

  if [[ "$WINDOWS_64" == true ]]; then
    build_icu "$WINDOWS_CLANG_TARGET_64" \
      x86_64-w64-mingw32 \
      "clang --target=x86_64-w64-windows-gnu" \
      "clang++ --target=x86_64-w64-windows-gnu" \
      llvm-ar llvm-ranlib \
      "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64" \
      "-O2" "-O2"
  fi

fi

# WASM builds
if [[ "$BUILD_WASM" == true ]]; then
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

  if [[ "$WASM32" == true ]]; then
    build_icu "wasm32" wasm32 emcc em++ emar emranlib "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_32"
    
    if [[ "$BUILD_LLVMIR" == true && "$LLVMIR32" == true ]]; then
      build_wasm_llvm_ir_variant 32
    fi
  fi
  if [[ "$WASM64" == true ]]; then
    build_icu "wasm64" wasm64 emcc em++ emar emranlib "--with-cross-build=$WORKDIR/build-$LINUX_CLANG_TARGET_64"
    
    if [[ "$BUILD_LLVMIR" == true && "$LLVMIR64" == true ]]; then
      build_wasm_llvm_ir_variant 64
    fi
  fi
fi

print_status "✅ ICU build is all complete."
