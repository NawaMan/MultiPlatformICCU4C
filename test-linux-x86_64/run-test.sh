#!/bin/bash

set -e

# Copy the ICU package to the test directory
cp ../dist/icu4c-77.1-linux-x86_64-clang-20.zip .

# Build the Docker image
docker build -t icu4c-linux-x86_64-test .

# Run the container
docker run --rm icu4c-linux-x86_64-test

# Clean up
rm -f icu4c-77.1-linux-x86_64-clang-20.zip
