FROM ubuntu:24.04

# Set environment variable for Clang version
ARG CLANG_VERSION=20
ARG ICU_VERSION=77.1

ENV CLANG_VERSION=${CLANG_VERSION}
ENV ICU_VERSION=${ICU_VERSION}

# Set non-interactive installation
ARG DEBIAN_FRONTEND=noninteractive

# Add i386 architecture
RUN dpkg --add-architecture i386 && \
    apt-get update

RUN apt-get update && apt-get install -y wget gnupg lsb-release software-properties-common
RUN wget https://apt.llvm.org/llvm.sh
RUN chmod +x llvm.sh || true
RUN ./llvm.sh ${CLANG_VERSION}

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    acl \
    autoconf \
    automake \
    build-essential \
    cmake \
    coreutils \
    curl \
    g++-multilib \
    gcc-multilib \
    git \
    libc6-dev-i386 \
    libstdc++-13-dev:i386 \
    libxml2-dev \
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
RUN update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-${CLANG_VERSION}   100 \
 && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 \
 && ln -sf /usr/bin/llvm-ar-${CLANG_VERSION}     /usr/bin/llvm-ar \
 && ln -sf /usr/bin/llvm-ranlib-${CLANG_VERSION} /usr/bin/llvm-ranlib

RUN which clang
RUN which clang++

# Set up working directory
WORKDIR /app

# Create directories for test files
RUN mkdir -p /app/icu

# Set environment variables
ENV ICU_DIR=/app/icu
ENV CXXFLAGS="-std=c++23 -fPIC"
ENV CFLAGS="-std=c23 -fPIC"

# The ICU package will be mounted from the host at runtime
# We'll use a volume mount in the run.sh script

# Copy test files
COPY ./CMakeLists.txt /app/
# Note: The shared test.cpp and common CMakeLists.txt will be mounted at runtime
# We don't copy them here to avoid issues with Docker build context

# Build and run commands will be provided in a separate script
COPY ./in-docker-run-test.sh /app/
RUN chmod +x /app/in-docker-run-test.sh || true

# Default command
CMD ["/bin/bash", "/app/in-docker-run-test.sh"]
