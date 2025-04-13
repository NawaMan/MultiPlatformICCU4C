#!/bin/bash

# build-lib-from-llvm.sh
# Compile LLVM IR (.ll) into .o and archive into .a static library

set -e

TARGET_TRIPLE=${1:-native}
OUTPUT_DIR=lib-from-llvm
SRC_DIR=llvm-ir
OBJ_DIR=$OUTPUT_DIR/obj
LIB_DIR=$OUTPUT_DIR/lib

print() {
    echo -e "\033[1;34m$1\033[0m"
}

print "🔍 Using LLVM IR from: $SRC_DIR"
mkdir -p "$OBJ_DIR" "$LIB_DIR"

print "🛠️  Compiling .ll to .o for target: $TARGET_TRIPLE ..."
find "$SRC_DIR" -name '*.ll' | while read -r f; do
    rel_path="${f#$SRC_DIR/}"
    out_dir="$OBJ_DIR/$(dirname "$rel_path")"
    mkdir -p "$out_dir"
    out_file="$out_dir/$(basename "$f" .ll).o"
    clang -c -target "$TARGET_TRIPLE" "$f" -o "$out_file"
done

print "📚 Creating static archive: libicu-llvm.a"
ar rcs "$LIB_DIR/libicu-llvm.a" $(find "$OBJ_DIR" -name '*.o')

print "✅ Done!"
print "   → Static library: $LIB_DIR/libicu-llvm.a"
print "   → Objects in:     $OBJ_DIR"
