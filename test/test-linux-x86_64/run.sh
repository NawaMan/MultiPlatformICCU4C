#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Building ICU4C test container (64-bit) ===${NC}"

# Get ICU and Clang versions from environment or use defaults from versions.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source versions if not already set
if [[ -z "$ICU_VERSION" || -z "$CLANG_VERSION" ]]; then
    source "$ROOT_DIR/versions.env"
    echo -e "Using versions from versions.env: ICU=${GREEN}$ICU_VERSION${NC}, Clang=${GREEN}$CLANG_VERSION${NC}"
fi

# Check if the ICU package exists
ICU_PACKAGE="$ROOT_DIR/dist/icu4c-${ICU_VERSION}-linux-x86_64-clang-${CLANG_VERSION}.zip"
if [[ ! -f "$ICU_PACKAGE" ]]; then
    echo -e "\n${YELLOW}ICU package not found: $ICU_PACKAGE${NC}"
    echo -e "Building ICU package first..."
    
    # Check if we should do a quick build
    if [[ "$(uname -s)" == "Linux" ]]; then
        echo -e "Running quick build on Linux..."
        (cd "$ROOT_DIR" && ./build.sh --quick)
    fi
    
    # Check again if the package exists
    if [[ ! -f "$ICU_PACKAGE" ]]; then
        echo -e "\n${YELLOW}Failed to build ICU package: $ICU_PACKAGE${NC}"
        exit 1
    fi
fi

# The ICU data file is included in the main package at share/icu/77.1/icudt77l.dat
# No need to check for a separate data package

echo -e "\n${YELLOW}=== Building and running test container ===${NC}"
echo -e "ICU Package: ${GREEN}$ICU_PACKAGE${NC}"

# Build the Docker image
docker build --no-cache \
    --build-arg ICU_VERSION=$ICU_VERSION \
    --build-arg CLANG_VERSION=$CLANG_VERSION \
    -t icu4c-test-linux-x86_64 .

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

VOLUMES="\
    -v "$ICU_PACKAGE:/app/icu4c-${ICU_VERSION}-linux-x86_64-clang-${CLANG_VERSION}.zip:ro" \
    -v "$SHARED_TEST_CPP:/app/test.cpp:ro" \
    -v "$SHARED_CMAKE:/app/CMakeLists.txt.common:ro""

docker run --rm $VOLUMES \
    icu4c-test-linux-x86_64

echo -e "\n${GREEN}✅ Tests completed successfully!${NC}"
