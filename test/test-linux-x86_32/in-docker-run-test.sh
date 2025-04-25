#!/bin/bash
set -e

# Extract the ICU package
echo "Extracting ICU package..."
rm -rf /app/icu
mkdir -p /app/icu_extract
cd /app/icu_extract
unzip -q /app/icu4c-${ICU_VERSION}-linux-x86_32-clang-${CLANG_VERSION}.zip

# Create the expected directory structure
mkdir -p /app/icu/lib /app/icu/include/unicode

# Copy libraries and headers to the expected locations
cp -r lib/* /app/icu/lib/
cp -r include/unicode/* /app/icu/include/unicode/

echo "Extraction complete."

# Instead of rebuilding ICU, let's create a wrapper library for C23 functions
echo "Creating compatibility wrapper for C23 functions..."
mkdir -p /app/compat
cd /app/compat

# Create a more comprehensive compatibility source file
cat > compat.c << 'EOF'
#include <stdlib.h>
#include <errno.h>
#include <stdio.h>

/* Compatibility stubs for C23 functions */
__attribute__((visibility("default")))
long int __isoc23_strtol(const char *nptr, char **endptr, int base) {
    return strtol(nptr, endptr, base);
}

__attribute__((visibility("default")))
unsigned long int __isoc23_strtoul(const char *nptr, char **endptr, int base) {
    return strtoul(nptr, endptr, base);
}

__attribute__((visibility("default")))
long long int __isoc23_strtoll(const char *nptr, char **endptr, int base) {
    return strtoll(nptr, endptr, base);
}

__attribute__((visibility("default")))
unsigned long long int __isoc23_strtoull(const char *nptr, char **endptr, int base) {
    return strtoull(nptr, endptr, base);
}

/* Additional C23 functions that might be needed */
__attribute__((visibility("default")))
double __isoc23_strtod(const char *nptr, char **endptr) {
    return strtod(nptr, endptr);
}

__attribute__((visibility("default")))
float __isoc23_strtof(const char *nptr, char **endptr) {
    return strtof(nptr, endptr);
}

__attribute__((visibility("default")))
long double __isoc23_strtold(const char *nptr, char **endptr) {
    return strtold(nptr, endptr);
}
EOF

# Compile the compatibility library with Clang 20 and proper flags
clang-${CLANG_VERSION} -m32 -fPIC -shared -O2 -c compat.c -o compat.o
ar rcs libcompat.a compat.o

# Also create a shared library version for dynamic linking if needed
clang-${CLANG_VERSION} -m32 -fPIC -shared -O2 compat.c -o libcompat.so

# Create a wrapper script for the linker
cat > link_wrapper.sh << 'EOF'
#!/bin/bash

# Get the original command
ORIG_CMD="$@"

# Add our compatibility library to the link command
MODIFIED_CMD="${ORIG_CMD} /app/compat/libcompat.a"

# Run the modified command
eval $MODIFIED_CMD
EOF

chmod +x link_wrapper.sh

# Set up the environment to use our wrapper
export PATH="$PWD:$PATH"

echo "Compatibility wrapper created."
cd /app

# Display the package structure
echo "ICU package contents:"
ls -la

# Check if the ICU directories are properly set up
echo "
Checking ICU directories..."

# Check include directory
if [ ! -d "/app/icu/include/unicode" ]; then
    echo "ICU include directory not properly set up. Fixing..."
    mkdir -p /app/icu/include/unicode
    
    # Copy headers from the extracted package
    if [ -d "/app/icu_extract/include/unicode" ]; then
        cp -r /app/icu_extract/include/unicode/* /app/icu/include/unicode/
    fi
fi

# Check library directory
if [ ! -d "/app/icu/lib" ]; then
    echo "ICU library directory not properly set up. Fixing..."
    mkdir -p /app/icu/lib
    
    # Copy libraries from the extracted package
    if [ -d "/app/icu_extract/lib" ]; then
        cp -r /app/icu_extract/lib/* /app/icu/lib/
    fi
fi

# Verify the directories
echo "
ICU include directory:"
ls -la /app/icu/include/unicode | head -10

echo "
ICU library directory:"
ls -la /app/icu/lib

# Create build directory
mkdir -p /app/build
cd /app/build

# Configure and build the test program
echo "Configuring with CMake..."
# Ensure the common CMakeLists.txt is properly linked
if [ -f "/app/common_cmake.txt" ]; then
    # Rename the common CMakeLists.txt to match what's expected in the include statement
    cp /app/common_cmake.txt /app/CMakeLists.txt.common
    # Set ICU_ROOT environment variable for the test
    export ICU_ROOT="/app/icu"
fi

# Make sure we're using Clang 20 as specified
if [ ! -f "/usr/bin/clang-${CLANG_VERSION}" ]; then
    echo "Installing Clang ${CLANG_VERSION}..."
    apt-get update && apt-get install -y wget software-properties-common
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    apt-add-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-${CLANG_VERSION} main"
    apt-get update && apt-get install -y clang-${CLANG_VERSION} llvm-${CLANG_VERSION}
fi

# Create symlinks for clang
ln -sf /usr/bin/clang-${CLANG_VERSION} /usr/bin/clang
ln -sf /usr/bin/clang++-${CLANG_VERSION} /usr/bin/clang++

# Install additional dependencies needed for newer Clang
apt-get update && apt-get install -y libtinfo5 libc6-dev:i386

# Create a custom CMake toolchain file to handle ICU library linking properly
cat > /app/icu_toolchain.cmake << 'EOF'
set(CMAKE_C_COMPILER "clang")
set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -fPIC -D_GNU_SOURCE -m32")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c11 -fPIC -D_GNU_SOURCE -m32")

# Force older C standard
add_definitions(-D_ISOC11_SOURCE -U__STRICT_ANSI__)

# Use our wrapper script for linking
set(CMAKE_CXX_LINK_EXECUTABLE "/app/compat/link_wrapper.sh <CMAKE_CXX_COMPILER> <FLAGS> <CMAKE_CXX_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")


# Force static linking for ICU
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++ -static-libgcc -m32")

# Define ICU linking helper function
function(target_link_icu TARGET)
  target_compile_definitions(${TARGET} PRIVATE U_STATIC_IMPLEMENTATION)
  # Link ICU libraries in the correct order with proper flags
  target_link_libraries(${TARGET}
    -Wl,--whole-archive
    /app/icu/lib/libicudata.a
    -Wl,--no-whole-archive
    /app/compat/libcompat.a
    /app/icu/lib/libicui18n.a
    /app/icu/lib/libicuuc.a
    /app/icu/lib/libicuio.a
    pthread dl m stdc++)
endfunction()
EOF

# Enable ICU examples with our custom toolchain
cmake -DCMAKE_TOOLCHAIN_FILE=/app/icu_toolchain.cmake -DENABLE_ICU_EXAMPLES=ON ..

echo "Building test program..."
make

# Run the test program
echo -e "\nRunning ICU test program:\n"
./icu_test

echo -e "\nTest completed successfully!"
