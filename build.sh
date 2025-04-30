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

LINUX_CLANG_TARGET_32="linux-x86-32"
LINUX_CLANG_TARGET_64="linux-x86-64"

print "✅ Compiler version checked"
print ""



build_icu() {
  TARGET="$1"; HOST="$2"; CC="$3"; CXX="$4"; AR="$5"; RANLIB="$6"; EXTRA_FLAGS="$7";  EXTRA_CFLAGS="$8"; EXTRA_CXXFLAGS="$9" ZIP_FILE="${10}"
  print_section "Build ICU for $TARGET"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would build ICU for: TARGET=$TARGET HOST=$HOST CC=$CC CXX=$CXX AR=$AR RANLIB=$RANLIB EXTRA_FLAGS=[$EXTRA_FLAGS] EXTRA_CFLAGS=[$EXTRA_CFLAGS] EXTRA_CXXFLAGS=[$EXTRA_CXXFLAGS]"
    return 0
  fi
  

  BUILD_DIR="$WORKDIR/build-$TARGET"
  INSTALL_DIR="$DISTDIR/$TARGET"

  rm    -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p  "$BUILD_DIR" "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/include"
  cd "$BUILD_DIR"

  ICU_SOURCE="$WORKDIR/icu/source"
  local ENABLE_TOOLS="--disable-tools"
  [[ "$TARGET" == "$LINUX_CLANG_TARGET_32" || "$TARGET" == "$LINUX_CLANG_TARGET_64" ]] \
      && ENABLE_TOOLS="--enable-tools"

  CROSS_COMPILE_DIR="${EXTRA_FLAGS#--with-cross-build=}"
  if [[ "$CROSS_COMPILE_DIR" != "" && -d "$CROSS_COMPILE_DIR/bin" ]]; then
    # In the pipeline, the permission can be altered to be un-executable. This should fix it.
    print "Change permission"
    chmod 755 "$CROSS_COMPILE_DIR/bin"/* || true
  fi

  PKG_CONFIG_LIBDIR=                                \
  CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB"     \
  CFLAGS="$EXTRA_CFLAGS" CXXFLAGS="$EXTRA_CXXFLAGS" \
  "$ICU_SOURCE/configure"                           \
    --prefix="$INSTALL_DIR"                         \
    --host="$HOST"                                  \
    --enable-static                                 \
    --disable-shared                                \
    --with-data-packaging=archive                   \
    --disable-extras                                \
    --disable-tests                                 \
    --disable-samples                               \
    $ENABLE_TOOLS                                   \
    $EXTRA_FLAGS                                    \
    >> "$BUILDLOG" 2>&1
    

  make -j$(nproc) >> "$BUILDLOG" 2>&1
  make install    >> "$BUILDLOG" 2>&1

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
      mv "$BUILD_DATA_FILE" "$STANDARD_DATA_PATH"
      ICU_DATA_FILE="$STANDARD_DATA_PATH"
      print "  ✅ Copied ICU data file from build directory to: $ICU_DATA_FILE"
    else
      print "  ✅ No ICU data file found! Copy from source."
      cp "$ICU_SOURCE/data/in/icudt${ICU_VERSION%%.*}l.dat" "$STANDARD_DATA_PATH"
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

  chmod -R ugo+rwx "$WORKDIR" || true
  chmod -R ugo+rwx "$DISTDIR" || true
}


show-build-matrix


if [[ "$LINUX_32" == true ]]; then
  TOOLS="clang-${CLANG_VERSION}"
  TARGET="linux-x86-32"
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
  build_icu     \
    "$TARGET"   \
    ""          \
    clang       \
    clang++     \
    llvm-ar     \
    llvm-ranlib \
    ""          \
    "-O2 -m32"  \
    "-O2 -m32"  \
    "$ZIP_FILE"
fi
if [[ "$LINUX_64" == true ]]; then
  TOOLS="clang-${CLANG_VERSION}"
  TARGET="linux-x86-64"
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
  build_icu     \
    "$TARGET"   \
    ""          \
    clang       \
    clang++     \
    llvm-ar     \
    llvm-ranlib \
    ""          \
    "-O2"       \
    "-O2"       \
    "$ZIP_FILE"
fi

if [[ "$WINDOWS_32" == true ]]; then
  TOOLS="clang-${CLANG_VERSION}"
  TARGET="windows-x86-32"
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
  LINUX_BUILD_DIR="$WORKDIR/build-$LINUX_CLANG_TARGET_32"
  build_icu                                 \
    "$TARGET"                               \
    i686-w64-mingw32                        \
    "clang   --target=i686-w64-windows-gnu" \
    "clang++ --target=i686-w64-windows-gnu" \
    llvm-ar                                 \
    llvm-ranlib                             \
    "--with-cross-build=$LINUX_BUILD_DIR"   \
    "-O2"                                   \
    "-O2"                                   \
    "$ZIP_FILE"
fi

if [[ "$WINDOWS_64" == true ]]; then
  TOOLS="clang-${CLANG_VERSION}"
  TARGET="windows-x86-64"
  ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
  LINUX_BUILD_DIR="$WORKDIR/build-$LINUX_CLANG_TARGET_64"
  build_icu                                   \
    "$TARGET"                                 \
    x86_64-w64-mingw32                        \
    "clang   --target=x86_64-w64-windows-gnu" \
    "clang++ --target=x86_64-w64-windows-gnu" \
    llvm-ar                                   \
    llvm-ranlib                               \
    "--with-cross-build=$LINUX_BUILD_DIR"     \
    "-O2"                                     \
    "-O2"                                     \
    "$ZIP_FILE"
fi

# WASM builds
if [[ "$WASM32" == true || "$WASM64" == true ]]; then
  print_section "Build WEB ASM"
  if [ ! -d emsdk ]; then
    git clone https://github.com/emscripten-core/emsdk.git
  fi
  cd emsdk
  EMSDK=$(pwd)
  git switch $ENSDK_VERSION -c "v$ENSDK_VERSION"
  ./emsdk install latest    >> "$BUILDLOG" 2>&1
  ./emsdk activate latest   >> "$BUILDLOG" 2>&1
  cd -
  print ""

  source "$EMSDK/emsdk_env.sh"
  cp "$WORKDIR/icu/source/config/mh-linux" "$WORKDIR/icu/source/config/mh-unknown"

  if [[ "$WASM32" == true ]]; then
    TOOLS="clang-${CLANG_VERSION}_emsdk-${ENSDK_VERSION}"
    TARGET="wasm-32"
    ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
    LINUX_BUILD_DIR="$WORKDIR/build-$LINUX_CLANG_TARGET_32"
    build_icu                               \
      "wasm-32"                             \
      wasm32                                \
      emcc                                  \
      em++                                  \
      emar                                  \
      emranlib                              \
      "--with-cross-build=$LINUX_BUILD_DIR" \
      "-O2"                                 \
      "-O2"                                 \
      "$ZIP_FILE"
  fi
  if [[ "$WASM64" == true ]]; then
    TOOLS="clang-${CLANG_VERSION}_emsdk-${ENSDK_VERSION}"
    TARGET="wasm-64"
    ZIP_FILE="$DISTDIR/icu4c-${ICU_VERSION}_${TARGET}_${TOOLS}.zip"
    LINUX_BUILD_DIR="$WORKDIR/build-$LINUX_CLANG_TARGET_64"
    build_icu                               \
      "wasm-64"                             \
      wasm64                                \
      emcc                                  \
      em++                                  \
      emar                                  \
      emranlib                              \
      "--with-cross-build=$LINUX_BUILD_DIR" \
      "-O2"                                 \
      "-O2"                                 \
      "$ZIP_FILE"
  fi
fi

print_status "✅ ICU build is all complete."
