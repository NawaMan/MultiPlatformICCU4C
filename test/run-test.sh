#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section header
print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Function to print status
print_status() {
    echo -e "${BLUE}$1${NC}"
}

# Function to print error and exit
exit_with_error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

print_section "Testing ICU4C Library"

# Check if ICU directory exists
if [ ! -d "/app/icu" ]; then
    exit_with_error "ICU directory not found. Make sure to mount it correctly."
fi

# Find the ICU installation (look for linux-x86_64 directory)
ICU_DIR=$(find /app/icu -type d -name "linux-x86_64*" | head -n 1)

if [ -z "$ICU_DIR" ]; then
    exit_with_error "Could not find linux-x86_64 ICU build directory"
fi

print_status "Found ICU installation at: $ICU_DIR"

# Compile the test program
print_status "Compiling test program..."
g++ -std=c++11 -I"$ICU_DIR/include" -o test test.cpp -L"$ICU_DIR/lib" -licui18n -licuuc -licudata -licuio

if [ $? -ne 0 ]; then
    exit_with_error "Compilation failed"
fi

# Set LD_LIBRARY_PATH to find the ICU libraries at runtime
export LD_LIBRARY_PATH="$ICU_DIR/lib:$LD_LIBRARY_PATH"

# Run the test
print_status "Running test..."
./test

if [ $? -eq 0 ]; then
    print_status "✅ Test passed successfully!"
else
    exit_with_error "Test failed"
fi
