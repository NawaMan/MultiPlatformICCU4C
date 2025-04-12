FROM ubuntu:24.04

# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    tar \
    python3 \
    cmake \
    pkg-config \
    mingw-w64 \
    nodejs \
    npm \
    libxml2-dev \
    autoconf \
    automake \
    libtool \
    bison \
    flex \
    sed \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy the build script
COPY build.sh /app/

# Make the script executable
RUN chmod +x /app/build.sh

# Create the icu-dist directory
RUN mkdir -p /app/icu-dist

# Set the entrypoint to the build script
ENTRYPOINT ["/bin/bash", "/app/build.sh"]

# Define a volume for the output
VOLUME ["/app/icu-dist"]
