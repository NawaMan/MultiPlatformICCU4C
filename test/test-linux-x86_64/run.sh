#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Building ICU4C test container ===${NC}"

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

echo -e "\n${YELLOW}=== Building and running test container ===${NC}"
echo -e "ICU Package: ${GREEN}$ICU_PACKAGE${NC}"

# Build the Docker image
docker build --no-cache \
    --build-arg ICU_VERSION=$ICU_VERSION \
    --build-arg CLANG_VERSION=$CLANG_VERSION \
    -t icu4c-test-linux-x86_64 .

# Run the container
echo -e "\n${YELLOW}=== Running ICU4C tests ===${NC}"
docker run --rm icu4c-test-linux-x86_64

echo -e "\n${GREEN}✅ Tests completed successfully!${NC}"
