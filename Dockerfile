FROM ubuntu:24.04

# Set environment variable for Clang version
ARG CLANG_VERSION=18
ARG ICU_VERSION=77.1
ARG ENSDK_VERSION=4.0.6

ENV CLANG_VERSION=${CLANG_VERSION}
ENV ICU_VERSION=${ICU_VERSION}
ENV ENSDK_VERSION=${ENSDK_VERSION}

# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive

# Add i386 architecture
RUN dpkg --add-architecture i386 && \
    apt-get update

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    acl \
    autoconf \
    automake \
    binutils-mingw-w64 \
    bison \
    build-essential \
    clang-${CLANG_VERSION} \
    cmake \
    coreutils \
    curl \
    flex \
    g++-multilib \
    g++-mingw-w64 \
    gcc-multilib \
    git \
    libc++-18-dev \
    libc++abi-18-dev \
    libc6-dev-i386 \
    libstdc++-13-dev:i386 \
    libtool \
    libxml2-dev \
    lld-${CLANG_VERSION} \
    llvm-${CLANG_VERSION} \
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
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for clang and LLVM tools to be available without version suffix
RUN update-alternatives    --install /usr/bin/clang   clang   /usr/bin/clang-${CLANG_VERSION}   100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 \
    && ln -sf /usr/bin/llvm-ar-${CLANG_VERSION}     /usr/bin/llvm-ar                                \
    && ln -sf /usr/bin/llvm-ranlib-${CLANG_VERSION} /usr/bin/llvm-ranlib

# Set up working directory
WORKDIR /app

# Copy the build script
COPY build.sh      /app/
COPY versions.env  /app/
COPY common.source /app/
COPY artifacts /app/artifacts

# Make the script executable
RUN chmod +x /app/build.sh

# Set the entrypoint to the build script
ENTRYPOINT ["/bin/bash", "/app/build.sh"]

# Define a volume for the output
VOLUME ["/app/dist"]
