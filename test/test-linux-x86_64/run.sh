#!/bin/bash
set -e

BITNESS=64

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Building ICU4C test container (${BITNESS}-bit) ===${NC}"

# Get ICU and Clang versions from environment or use defaults from versions.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source versions if not already set
if [[ -z "$ICU_VERSION" || -z "$CLANG_VERSION" ]]; then
    source "$ROOT_DIR/versions.env"
    echo -e "Using versions from versions.env: ICU=${GREEN}$ICU_VERSION${NC}, Clang=${GREEN}$CLANG_VERSION${NC}"
fi

# Check if the ICU package exists
ICU_PACKAGE="$ROOT_DIR/dist/icu4c-${ICU_VERSION}_linux-x86-${BITNESS}_clang-${CLANG_VERSION}.zip"
if [[ ! -f "$ICU_PACKAGE" ]]; then
    echo -e "\n${YELLOW}ICU package not found: $ICU_PACKAGE${NC}"
    echo -e "Building ICU package first..."
    
    # Check if we should do a quick build
    if [[ "$(uname -s)" == "Linux" ]]; then
        echo -e "Running build with LINUX_${BITNESS}=true..."
        (cd "$ROOT_DIR" && export LINUX_${BITNESS}=true && ./build.sh)
    fi
    
    # Check again if the package exists
    if [[ ! -f "$ICU_PACKAGE" ]]; then
        echo -e "\n${YELLOW}Failed to build ICU package: $ICU_PACKAGE${NC}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}=== Building and running test container ===${NC}"
echo -e "ICU Package: ${GREEN}$ICU_PACKAGE${NC}"

# Build the Docker image
docker build --no-cache                      \
    --build-arg ICU_VERSION=$ICU_VERSION     \
    --build-arg CLANG_VERSION=$CLANG_VERSION \
    --build-arg BITNESS=$BITNESS             \
    -t icu4c-test-linux-x86_$BITNESS .

# Run the container with volumes for ICU package and shared test files
echo -e "\n${YELLOW}=== Running ICU4C tests ===${NC}"

# Ensure shared test files are available
SHARED_TEST_CPP="$SCRIPT_DIR/../test.cpp"
SHARED_CMAKE="$SCRIPT_DIR/../CMakeLists.txt"

if [[ ! -f "$SHARED_TEST_CPP" ]]; then
    echo -e "${YELLOW}Error: Shared test.cpp not found at $SHARED_TEST_CPP${NC}"
    exit 1
fi

if [[ ! -f "$SHARED_CMAKE" ]]; then
    echo -e "${YELLOW}Error: Shared CMakeLists.txt not found at $SHARED_CMAKE${NC}"
    exit 1
fi

# Run the container with all necessary volumes
echo -e "\n${YELLOW}=== Running ICU4C tests ===${NC}"
docker run --rm \
    -v "$ICU_PACKAGE:/app/icu4c-${ICU_VERSION}_linux-x86-${BITNESS}_clang-${CLANG_VERSION}.zip:ro" \
    -v "$SHARED_TEST_CPP:/app/test.cpp:ro"                                                         \
    -v "$SHARED_CMAKE:/app/CMakeLists.txt.common:ro"                                               \
    icu4c-test-linux-x86_$BITNESS

echo -e "\n${GREEN}✅ Tests completed successfully!${NC}"
