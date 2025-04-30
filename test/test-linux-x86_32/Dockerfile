# Start from a newer Ubuntu with glibc 2.39 (C23 support)
FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install multiarch support for 32-bit builds
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    gcc-multilib g++-multilib \
    build-essential \
    cmake \
    wget \
    unzip \
    libstdc++-13-dev:i386 \
    libc6-dev:i386 \
    libgcc-13-dev:i386 \
    software-properties-common \
    gnupg \
    lsb-release \
    make \
    autoconf \
    automake \
    libtool \
    pkg-config \
    python3 \
    curl

# Set build arguments
ARG ICU_VERSION=77.1
ARG CLANG_VERSION=20

# Set environment variables
ENV ICU_VERSION=${ICU_VERSION}
ENV CLANG_VERSION=${CLANG_VERSION}

# Install LLVM/Clang
RUN wget https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh || true && \
    ./llvm.sh ${CLANG_VERSION} && \
    rm llvm.sh

# Create symlinks for clang and LLVM tools
RUN update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-${CLANG_VERSION} 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 && \
    ln -sf /usr/bin/llvm-ar-${CLANG_VERSION} /usr/bin/llvm-ar && \
    ln -sf /usr/bin/llvm-ranlib-${CLANG_VERSION} /usr/bin/llvm-ranlib

RUN which clang
RUN which clang++

# Set up working directory
WORKDIR /app

# Create directories for test files
RUN mkdir -p /app/icu

# Set environment variables for 32-bit C++23 build
ENV CXXFLAGS="-std=c++23 -fPIC -m32"
ENV CFLAGS="-std=c23 -fPIC -m32"
ENV LDFLAGS="-m32"

# Copy CMakeLists.txt and build script
COPY ./CMakeLists.txt /app/
COPY ./in-docker-run-test.sh /app/
RUN chmod +x /app/in-docker-run-test.sh || true

# Default command
CMD ["/bin/bash", "/app/in-docker-run-test.sh"]
