FROM ubuntu:22.04

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    make \
    cmake \
    unzip \
    libstdc++-10-dev \
    libdl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV CC=clang
ENV CXX=clang++

# Create app directory
WORKDIR /app

# Copy the ICU4C package
COPY ./icu4c-77.1-linux-x86_64-clang-20.zip /app/

# Extract the ICU4C package
RUN unzip icu4c-77.1-linux-x86_64-clang-20.zip -d /app/icu

# Copy the test code
COPY ./test.cpp /app/
COPY ./CMakeLists.txt /app/

# Build the test program
RUN mkdir -p /app/build && \
    cd /app/build && \
    cmake .. -DCMAKE_VERBOSE_MAKEFILE=ON && \
    make VERBOSE=1

# Run the test program
CMD ["/app/build/icu_test"]
