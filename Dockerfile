FROM ubuntu:24.04

# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    bison \
    build-essential \
    clang-18 \
    cmake \
    flex \
    g++-multilib \
    gcc-multilib \
    git \
    libc++-18-dev \
    libc++abi-18-dev \
    libtool \
    libxml2-dev \
    lld-18 \
    llvm-18 \
    mingw-w64 \
    nodejs \
    npm \
    pkg-config \
    python3 \
    rsync \
    sed \
    tar \
    tree \
    unzip \
    wget \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

    # Create symlinks for clang-18 and LLVM tools to be available without version suffix
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100 \
    && ln -sf /usr/bin/llvm-ar-18 /usr/bin/llvm-ar \
    && ln -sf /usr/bin/llvm-ranlib-18 /usr/bin/llvm-ranlib

# Set up working directory
WORKDIR /app

# Copy the build script
COPY build.sh  /app/
COPY artifacts /app/artifacts

# Make the script executable
RUN chmod +x /app/build.sh

# Create the icu-dist directory
RUN mkdir -p /app/dist

# Set the entrypoint to the build script
ENTRYPOINT ["/bin/bash", "/app/build.sh"]

# Define a volume for the output
VOLUME ["/app/dist"]
