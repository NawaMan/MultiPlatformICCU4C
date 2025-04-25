#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Setting up ICU4C test for WebAssembly (64-bit) ===${NC}"

# Get ICU and Emscripten versions from environment or use defaults from versions.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source versions if not already set
if [[ -z "$ICU_VERSION" || -z "$ENSDK_VERSION" ]]; then
    source "$ROOT_DIR/versions.env"
    echo -e "Using versions from versions.env: ICU=${GREEN}$ICU_VERSION${NC}, Emscripten=${GREEN}$ENSDK_VERSION${NC}"
fi

# Check if the ICU package exists
# Using wasm32 package since the wasm64 package contains 32-bit libraries
ICU_PACKAGE="$ROOT_DIR/dist/icu4c-${ICU_VERSION}-wasm32.zip"
if [[ ! -f "$ICU_PACKAGE" ]]; then
    echo -e "\n${YELLOW}ICU package not found: $ICU_PACKAGE${NC}"
    echo -e "Building ICU package first..."
    
    # Check if we should do a quick build
    if [[ "$(uname -s)" == "Linux" ]]; then
        echo -e "Running build with WASM_64=true..."
        (cd "$ROOT_DIR" && export WASM_64=true && ./build.sh)
    else
        echo -e "Running full build..."
        (cd "$ROOT_DIR" && ./full-build.sh)
    fi
    
    # Check again if the package exists
    if [[ ! -f "$ICU_PACKAGE" ]]; then
        echo -e "\n${YELLOW}Failed to build ICU package: $ICU_PACKAGE${NC}"
        exit 1
    fi
fi

# Set up Emscripten environment
echo -e "\n${YELLOW}=== Setting up Emscripten environment ===${NC}"
if [[ ! -d "$ROOT_DIR/build/emsdk" ]]; then
    echo -e "Emscripten SDK not found. Cloning and setting up..."
    mkdir -p "$ROOT_DIR/build"
    cd "$ROOT_DIR/build"
    git clone https://github.com/emscripten-core/emsdk.git
    cd emsdk
    ./emsdk install $ENSDK_VERSION
    ./emsdk activate $ENSDK_VERSION
fi

# Source Emscripten environment
cd "$ROOT_DIR/build/emsdk"
source ./emsdk_env.sh

# Create test directory
TEST_DIR="$(mktemp -d)"
echo -e "\n${YELLOW}=== Creating test environment in ${TEST_DIR} ===${NC}"

# Extract the ICU package
echo -e "Extracting ICU package to ${TEST_DIR}/icu..."
mkdir -p "${TEST_DIR}/icu"
cd "${TEST_DIR}/icu"
unzip -q "$ICU_PACKAGE"

# Copy test files
echo -e "Copying test files..."

# Check if test.cpp exists
if [[ ! -f "$SCRIPT_DIR/../test.cpp" ]]; then
    echo -e "${YELLOW}Error: test.cpp not found at $SCRIPT_DIR/../test.cpp${NC}"
    exit 1
fi

# Copy test files with verbose output
echo -e "Copying test.cpp from $SCRIPT_DIR/../test.cpp to ${TEST_DIR}/"
cp -v "$SCRIPT_DIR/../test.cpp" "${TEST_DIR}/"
cp -v "$SCRIPT_DIR/CMakeLists.txt" "${TEST_DIR}/"
cp -v "$SCRIPT_DIR/../CMakeLists.txt" "${TEST_DIR}/CMakeLists.txt.common"

# Create build directory
mkdir -p "${TEST_DIR}/build"
cd "${TEST_DIR}/build"

# Configure and build with Emscripten
echo -e "${YELLOW}=== Configuring and building test ===${NC}"

# We're only using the common test.cpp file
# No need to copy any additional test files

# Configure with CMake using Emscripten
export ICU_ROOT="/app/icu"

# Configure with CMake using Emscripten toolchain
emcmake cmake \
    -DENABLE_ICU_EXAMPLES=ON \
    -DICU_ROOT="${TEST_DIR}/icu" \
    -DPRELOAD_ICU=ON \
    "${TEST_DIR}"

# Build
echo -e "Building test program..."
emmake make

# Run the test using Node.js
echo -e "\n${YELLOW}=== Running WebAssembly 64-bit Tests ===${NC}"

# Display the list of tests that will be run
echo -e "${GREEN}Available Tests:${NC}"
echo -e "  ${GREEN}✓${NC} WebAssembly 64-bit Memory Test"
echo -e "  ${GREEN}✓${NC} ICU Package Verification"
echo -e "  ${GREEN}✓${NC} Unicode String Example"
echo -e "  ${GREEN}✓${NC} Locale Example"
echo -e "  ${GREEN}✓${NC} Break Iterator Example"
echo -e "  ${GREEN}✓${NC} Transliteration Example"
echo -e "  ${GREEN}✓${NC} ICU Data Bundle Verification"
echo -e "    - Character properties data"
echo -e "    - Collation data"
echo -e "    - Calendar data"
echo -e "    - Resource bundle data"
echo -e "    - Converter data"

# First run the WASM64 memory test
echo -e "\n${YELLOW}=== Running WebAssembly 64-bit Memory Test ===${NC}"
node --experimental-wasm-memory64 wasm64_test.js

# Then run the ICU test
echo -e "\n${YELLOW}=== Running ICU4C tests (WASM 64-bit) ===${NC}"
node --experimental-wasm-memory64 icu_test.js

# Clean up
echo -e "\n${YELLOW}=== Cleaning up ===${NC}"
rm -rf "${TEST_DIR}"

echo -e "\n${GREEN}\u2705 Tests completed successfully!${NC}"
