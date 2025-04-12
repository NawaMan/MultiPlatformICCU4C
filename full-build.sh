#!/bin/bash

# Build the Docker image
docker build . -t icu4c-builder

# Create icu-dist directory if it doesn't exist
mkdir -p $(pwd)/icu-dist

# Run the container with volume mapping for icu-dist
docker run --rm -v $(pwd)/icu-dist:/app/icu-dist icu4c-builder:latest
