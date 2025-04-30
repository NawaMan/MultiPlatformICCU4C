FROM ubuntu:24.04

# Set environment variable for Clang version
ARG CPP_VERSION=23
ARG BITNESS=64
ARG CLANG_VERSION=20
ARG ICU_VERSION=77.1
ARG ENSDK_VERSION=4.0.6

ENV BITNESS=${BITNESS}
ENV CPP_VERSION=${CPP_VERSION}
ENV CLANG_VERSION=${CLANG_VERSION}
ENV ICU_VERSION=${ICU_VERSION}
ENV ENSDK_VERSION=${ENSDK_VERSION}

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update                 \
 && apt-get install -y             \
        acl                        \
        autoconf                   \
        automake                   \
        build-essential            \
        cmake                      \
        curl                       \
        g++-multilib               \
        gcc-multilib               \
        gnupg                      \
        lsb-release                \
        pkg-config                 \
        python3                    \
        software-properties-common \
        unzip                      \
        wget

    # Install LLVM/Clang
    RUN wget https://apt.llvm.org/llvm.sh && \
        chmod +x llvm.sh || true &&          \
        ./llvm.sh ${CLANG_VERSION} &&        \
        rm llvm.sh

# Create symlinks for clang and LLVM tools to be available without version suffix
RUN update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-${CLANG_VERSION}   100 \
 && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} 100 \
 && ln -sf /usr/bin/llvm-ar-${CLANG_VERSION} /usr/bin/llvm-ar \
 && ln -sf /usr/bin/llvm-ranlib-${CLANG_VERSION} /usr/bin/llvm-ranlib

# Set up working directory
WORKDIR /app

# Create directories for test files
RUN mkdir -p /app/icu

# Set environment variables
# ENV ICU_DIR=/app/icu
ENV CXXFLAGS="-std=c++${CPP_VERSION} -fPIC -m${BITNESS}"
ENV CFLAGS="-std=c${CPP_VERSION} -fPIC -m${BITNESS}"
ENV LDFLAGS="-m${BITNESS}"

# Copy files
COPY ./CMakeLists.txt /app/
COPY ./in-docker-run-test.sh /app/
RUN chmod +x /app/in-docker-run-test.sh || true

# Default command
CMD ["/bin/bash", "/app/in-docker-run-test.sh"]
