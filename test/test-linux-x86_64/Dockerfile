FROM ubuntu:24.04

ARG ICU_VERSION=77.1
ARG CLANG_VERSION=20

ENV ICU_VERSION=${ICU_VERSION}
ENV CLANG_VERSION=${CLANG_VERSION}

# Install necessary packages
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    wget \
    unzip \
    libicu-dev \
    gnupg \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install LLVM and Clang
RUN wget https://apt.llvm.org/llvm.sh \
 && chmod +x llvm.sh \
 && ./llvm.sh ${CLANG_VERSION} \
 && rm llvm.sh

# Create symlinks for clang and LLVM tools
RUN update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-${CLANG_VERSION} 100 \
 && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 \
 && ln -sf /usr/bin/llvm-ar-${CLANG_VERSION} /usr/bin/llvm-ar \
 && ln -sf /usr/bin/llvm-ranlib-${CLANG_VERSION} /usr/bin/llvm-ranlib

# Set up working directory
WORKDIR /app

# Create directories for test files
RUN mkdir -p /app/icu

# Set environment variables
ENV ICU_DIR=/app/icu
ENV CXXFLAGS="-std=c++17 -fPIC"
ENV CFLAGS="-std=c11 -fPIC"

# We'll copy the ICU package during the build process
COPY ./icu4c-${ICU_VERSION}-linux-x86_64-clang-${CLANG_VERSION}.zip /app/

# Create test files
COPY ./test.cpp       /app/
COPY ./CMakeLists.txt /app/

# Build and run commands will be provided in a separate script
COPY ./run-test.sh /app/
RUN chmod +x /app/run-test.sh

# Default command
CMD ["/bin/bash", "/app/run-test.sh"]
