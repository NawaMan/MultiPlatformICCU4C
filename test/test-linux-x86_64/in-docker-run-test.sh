#!/bin/bash
set -e

# Extract the ICU package
echo "Extracting ICU package..."
rm -rf /app/icu /app/icu_data
mkdir -p /app/icu /app/icu_data
cd /app/icu
unzip -q /app/icu4c-${ICU_VERSION}-linux-x86_64-clang-${CLANG_VERSION}.zip
echo "Extraction complete."

# Set up ICU data path - ensure the data file is properly located
if [ -f "/app/icu/share/icu/${ICU_VERSION}/icudt*l.dat" ]; then
    echo "Found ICU data file in share/icu/${ICU_VERSION}/"
    # Create a symlink to make it easier to find
    mkdir -p /app/icu_data
    ln -sf /app/icu/share/icu/${ICU_VERSION}/icudt*l.dat /app/icu_data/
    # Set environment variable for ICU data
    export ICU_DATA="/app/icu_data"
fi

# Display the package structure
echo "ICU package contents:"
ls -la

# Check if include directory exists
if [ -d "include/unicode" ]; then
    echo "
ICU include directory found!"
    ls -la include/unicode | head -10
else
    echo "
ICU include directory not found. Creating from source..."
    
    # Create include directory structure
    mkdir -p include/unicode
    
    # Copy header files from common, i18n, and io directories
    if [ -d "common" ]; then
        echo "Copying headers from common directory..."
        find common -name "*.h" -exec cp {} include/unicode/ \;
    fi
    
    if [ -d "i18n" ]; then
        echo "Copying headers from i18n directory..."
        find i18n -name "*.h" -exec cp {} include/unicode/ \;
    fi
    
    if [ -d "io" ]; then
        echo "Copying headers from io directory..."
        find io -name "*.h" -exec cp {} include/unicode/ \;
    fi
    
    echo "Headers copied to include/unicode/"
    ls -la include/unicode | head -10
fi

# Check for ICU data files
echo "
Checking for ICU data file..."

# Check for the ICU data file in the known location
DATA_FILE="/app/icu/share/icu/${ICU_VERSION}/icudt${ICU_VERSION%%.*}l.dat"

if [ -f "$DATA_FILE" ]; then
    echo "Found ICU data file: $DATA_FILE"
    
    # Create a directory for the data file and set up environment variable
    mkdir -p /app/icu_data
    ln -sf "$DATA_FILE" /app/icu_data/
    export ICU_DATA="/app/icu_data"
    
    # Verify the symlink works
    echo "Verifying ICU data file access:"
    ls -la /app/icu_data/
    
    cd /app/icu
else
    echo "ERROR: ICU data file not found at $DATA_FILE"
    echo "Contents of /app/icu/share/icu/${ICU_VERSION}/ (if it exists):"
    ls -la /app/icu/share/icu/${ICU_VERSION}/ 2>/dev/null || echo "Directory does not exist"
    exit 1
fi

# Check library directory
echo "
ICU library directory:"
ls -la lib

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

# Create a custom CMake toolchain file to handle ICU library linking properly
cat > /app/icu_toolchain.cmake << 'EOF'
set(CMAKE_C_COMPILER "clang")
set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -fPIC -D_GNU_SOURCE")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c11 -fPIC -D_GNU_SOURCE")

# Force static linking for ICU
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++ -static-libgcc")

# Define ICU linking helper function
function(target_link_icu TARGET)
  target_compile_definitions(${TARGET} PRIVATE U_STATIC_IMPLEMENTATION)
  # Link ICU libraries in the correct order with proper flags
  target_link_libraries(${TARGET}
    -Wl,--whole-archive
    /app/icu/lib/libicudata.a
    -Wl,--no-whole-archive
    /app/icu/lib/libicui18n.a
    /app/icu/lib/libicuuc.a
    /app/icu/lib/libicuio.a
    pthread dl m stdc++)
endfunction()
EOF

# Enable ICU examples with our custom toolchain and set ICU data path
cmake -DCMAKE_TOOLCHAIN_FILE=/app/icu_toolchain.cmake -DENABLE_ICU_EXAMPLES=ON -DICU_DATA_DIR=/app/icu_data ..

echo "Building test program..."
make

# Run the test program with ICU_DATA environment variable
echo -e "\nRunning ICU test program:\n"

# Make sure ICU_DATA is set correctly
if [ -z "$ICU_DATA" ]; then
    # If not already set, try to find the data file
    if [ -f "/app/icu_data/icudt*l.dat" ]; then
        export ICU_DATA="/app/icu_data"
    elif [ -f "/app/icu/share/icu/${ICU_VERSION}/icudt*l.dat" ]; then
        export ICU_DATA="/app/icu/share/icu/${ICU_VERSION}"
    fi
fi

echo "Using ICU_DATA=$ICU_DATA"
./icu_test

echo -e "\nTest completed successfully!"
