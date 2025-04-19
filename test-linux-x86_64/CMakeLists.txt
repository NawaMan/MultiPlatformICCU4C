cmake_minimum_required(VERSION 3.10)
project(ICU_Test)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set ICU directory
set(ICU_DIR ${CMAKE_SOURCE_DIR}/icu)

# Include directories
include_directories(${ICU_DIR}/include)

# Find ICU libraries
file(GLOB ICU_LIBS "${ICU_DIR}/lib/*.a")

# Create executable
add_executable(icu_test test.cpp)

# Add necessary compiler flags for static ICU
target_compile_definitions(icu_test PRIVATE U_STATIC_IMPLEMENTATION)

# Add additional linker flags if needed
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -ldl -pthread")

# Link with ICU libraries - specify the order explicitly for static linking
target_link_libraries(icu_test ${ICU_LIBS} dl pthread)

# Print found libraries for debugging
message(STATUS "Found ICU libraries: ${ICU_LIBS}")
