#!/bin/bash

DISTDIR=dist

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


# Build
./build.sh --clean --quick

# Done
echo ""
print_status "✅ ICU build complete. Output in: $DISTDIR"
print_status "Built directories:"
ls -ld "$DISTDIR/"*/

print_status "Zip archives:"
ls -l "$DISTDIR"/*.zip
