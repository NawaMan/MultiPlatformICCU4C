#!/bin/bash

# icu-cross-build.sh: Cross-compile ICU4C as static library for multiple platforms
# Platforms: linux-x86_64, windows-x86_64 (MinGW), wasm32 (Emscripten)

set -e

ICU_VERSION="74.2"
ICU_MAJ_VER="74"
ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION//./-}/icu4c-${ICU_VERSION//./_}-src.tgz"

if [ ! -d emsdk ]; then
  git clone https://github.com/emscripten-core/emsdk.git
fi

cd emsdk
EMSDK=$(pwd)
git checkout 4.0.6
./emsdk install latest
./emsdk activate latest
cd -

WORKDIR=$(pwd)/icu-build
DISTDIR=$(pwd)/icu-dist

mkdir -p "$WORKDIR" "$DISTDIR"
cd "$WORKDIR"

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

  echo "\n=== Building ICU for $TARGET ==="

  BUILD_DIR="$WORKDIR/build-$TARGET"
  INSTALL_DIR="$DISTDIR/$TARGET"

  rm -rf "$BUILD_DIR" "$INSTALL_DIR"
  mkdir -p "$BUILD_DIR"
  mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/include"
  cd "$BUILD_DIR"

  ICU_SOURCE="$WORKDIR/icu/source"

  local ENABLE_TOOLS="--disable-tools"
  if [ "$TARGET" = "linux-x86_64" ]; then
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
build_icu "linux-x86_64" "" gcc g++ ar ranlib

# Windows x86_64 (MinGW)
build_icu "windows-x86_64" \
  x86_64-w64-mingw32 \
  x86_64-w64-mingw32-gcc \
  x86_64-w64-mingw32-g++ \
  x86_64-w64-mingw32-ar \
  x86_64-w64-mingw32-ranlib \
  "--with-cross-build=$WORKDIR/build-linux-x86_64"

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
  "--with-cross-build=$WORKDIR/build-linux-x86_64"


# Done
echo "\n✅ ICU build complete. Output in: $DISTDIR"
ls -l $DISTDIR
