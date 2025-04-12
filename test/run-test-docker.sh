#!/bin/bash

# Directory containing this script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Parent directory (project root)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# ICU dist directory
ICU_DIST="$PROJECT_ROOT/icu-dist"

# Check if ICU dist directory exists
if [ ! -d "$ICU_DIST" ]; then
    echo "ERROR: ICU dist directory not found at $ICU_DIST"
    echo "Please build ICU first using ./full-build.sh"
    exit 1
fi

# Build the test Docker image
echo "Building test Docker image..."
docker build -t icu4c-test -f "$SCRIPT_DIR/Dockerfile.test" "$SCRIPT_DIR"

# Run the test container with the ICU libraries mounted
echo "Running test..."
docker run --rm -v "$ICU_DIST:/app/icu" icu4c-test:latest

echo "Test completed."
