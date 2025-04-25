#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Setting up ICU4C test (32-bit) ===${NC}"

# Get ICU and Clang versions from environment or use defaults from versions.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source versions if not already set
if [[ -z "$ICU_VERSION" || -z "$CLANG_VERSION" ]]; then
    source "$ROOT_DIR/versions.env"
    echo -e "Using versions from versions.env: ICU=${GREEN}$ICU_VERSION${NC}, Clang=${GREEN}$CLANG_VERSION${NC}"
fi

# Check if the ICU package exists
ICU_PACKAGE="$ROOT_DIR/dist/icu4c-${ICU_VERSION}-linux-x86_32-clang-${CLANG_VERSION}.zip"
if [[ ! -f "$ICU_PACKAGE" ]]; then
    echo -e "\n${YELLOW}ICU package not found: $ICU_PACKAGE${NC}"
    echo -e "Building ICU package first..."
    
    # Check if we should do a quick build
    if [[ "$(uname -s)" == "Linux" ]]; then
        echo -e "Running build with LINUX_32=true..."
        (cd "$ROOT_DIR" && export LINUX_32=true && ./build.sh)
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

# Create a temporary directory for testing
TEST_DIR="$(mktemp -d)"
echo -e "\n${YELLOW}=== Creating test environment in ${TEST_DIR} ===${NC}"

# Extract the ICU package
echo -e "Extracting ICU package to ${TEST_DIR}/icu..."
mkdir -p "${TEST_DIR}/icu"
cd "${TEST_DIR}/icu"
unzip -q "$ICU_PACKAGE"

# Copy test files
echo -e "Copying test files..."
cp "$SCRIPT_DIR/../test.cpp" "${TEST_DIR}/"
cp "$SCRIPT_DIR/CMakeLists.txt" "${TEST_DIR}/"
cp "$SCRIPT_DIR/../CMakeLists.txt" "${TEST_DIR}/CMakeLists.txt.common"

# Create build directory
mkdir -p "${TEST_DIR}/build"
cd "${TEST_DIR}/build"

# Create a custom CMake toolchain file
echo -e "Creating toolchain file..."
cat > "${TEST_DIR}/icu_toolchain.cmake" << 'EOF'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR i686)

set(CMAKE_C_COMPILER "clang")
set(CMAKE_CXX_COMPILER "clang++")

# Force 32-bit compilation
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32 -fPIC")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32 -fPIC -std=c++17")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -m32")

# Force static linking
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)

# Define ICU linking helper function
function(target_link_icu TARGET)
  target_compile_definitions(${TARGET} PRIVATE U_STATIC_IMPLEMENTATION)
  # Link ICU libraries in the correct order
  target_link_libraries(${TARGET}
    -Wl,--whole-archive
    ${ICU_ROOT}/lib/libicudata.a
    -Wl,--no-whole-archive
    ${ICU_ROOT}/lib/libicui18n.a
    ${ICU_ROOT}/lib/libicuuc.a
    ${ICU_ROOT}/lib/libicuio.a
    pthread dl m stdc++)
endfunction()
EOF

# Configure and build
echo -e "${YELLOW}=== Configuring and building test ===${NC}"
export ICU_ROOT="${TEST_DIR}/icu"

# Check for multilib support
if ! dpkg -l | grep -q "g++-multilib"; then
    echo -e "${YELLOW}Installing multilib support (requires sudo)...${NC}"
    sudo apt-get update && sudo apt-get install -y gcc-multilib g++-multilib
fi

# Configure with CMake
cmake -DCMAKE_TOOLCHAIN_FILE="${TEST_DIR}/icu_toolchain.cmake" \
      -DENABLE_ICU_EXAMPLES=ON \
      "${TEST_DIR}"

# Build
echo -e "Building test program..."
make

# Run the test
echo -e "\n${YELLOW}=== Running ICU4C tests (32-bit) ===${NC}"
./icu_test

# Clean up
echo -e "\n${YELLOW}=== Cleaning up ===${NC}"
rm -rf "${TEST_DIR}"

echo -e "\n${GREEN}✅ Tests completed successfully!${NC}"
