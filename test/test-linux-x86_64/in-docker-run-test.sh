#!/bin/bash
set -e

# Extract the ICU package
echo "Extracting ICU package..."
rm -rf /app/icu
mkdir -p /app/icu
cd /app/icu
unzip -q /app/icu4c-${ICU_VERSION}-linux-x86_64-clang-${CLANG_VERSION}.zip
echo "Extraction complete."

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

# Check library directory
echo "
ICU library directory:"
ls -la lib

# Create build directory
mkdir -p /app/build
cd /app/build

# Configure and build the test program
echo "Configuring with CMake..."
# Enable ICU examples with the newer Ubuntu version
cmake -DENABLE_ICU_EXAMPLES=ON ..

echo "Building test program..."
make

# Run the test program
echo -e "\nRunning ICU test program:\n"
./icu_test

echo -e "\nTest completed successfully!"
