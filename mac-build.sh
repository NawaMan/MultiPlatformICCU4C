#!/bin/bash
set -e

VERSION="${1:-dev}"
ARCH="${2:-x86_64}"  # Accept "x86_64", "arm64", or "universal"

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

  # Combine each static library with lipo
  for libfile in "$WORKDIR/x86_64/install/lib"/*.a; do
    base=$(basename "$libfile")
    lipo -create \
      "$WORKDIR/x86_64/install/lib/$base" \
      "$WORKDIR/arm64/install/lib/$base" \
      -output "$OUTDIR/lib/$base"
  done

  # Use x86_64's headers (same across builds)
  cp -r "$WORKDIR/x86_64/install/include" "$OUTDIR/"

  ZIP_NAME="icu4c-${VERSION}-macos-universal.zip"
  cd "$OUTDIR"
  zip -r "$DISTDIR/$ZIP_NAME" . > /dev/null
  echo "✅ Created: dist/$ZIP_NAME"
}

package_single_arch() {
  ARCH_DIR="$WORKDIR/$ARCH/install"
  OUT_NAME="icu4c-${VERSION}-macos-${ARCH}.zip"

  cd "$ARCH_DIR"
  zip -r "$DISTDIR/$OUT_NAME" . > /dev/null
  echo "✅ Created: dist/$OUT_NAME"
}

# Main
echo "📦 mac-build.sh - Building ICU $VERSION for $ARCH"
echo "🔍 ICU source expected in: $ICU_SOURCE"
echo

if [[ ! -d "$ICU_SOURCE" ]]; then
  echo "❌ ICU source directory not found: $ICU_SOURCE"
  echo "Make sure to run ./build.sh once to unpack the source."
  exit 1
fi

case "$ARCH" in
  universal)
    build_arch x86_64 x86_64-apple-darwin
    build_arch arm64 arm-apple-darwin
    merge_universal
    ;;
  x86_64|arm64)
    build_arch "$ARCH" "$ARCH-apple-darwin"
    package_single_arch
    ;;
  *)
    echo "❌ Unknown architecture: $ARCH"
    echo "Supported values: x86_64, arm64, universal"
    exit 1
    ;;
esac
