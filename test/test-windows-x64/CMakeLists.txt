cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set bitness for this platform
set(BITNESS 64)

# Set platform-specific ICU directory
if(NOT DEFINED ICU_ROOT)
    set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)
endif()

# Windows-specific settings
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
add_compile_definitions(NOMINMAX) # Avoid Windows min/max macros

# Use static libraries for Windows
set(BUILD_SHARED_LIBS OFF)

# Set C++ standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add ICU include directory
include_directories(${ICU_ROOT}/include)

# Try to include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    # If common CMakeLists.txt not found, create a minimal test setup
    message(WARNING "Could not find common CMakeLists.txt, creating minimal test setup")

    # Add the test executable
    add_executable(icu_test ${CMAKE_CURRENT_SOURCE_DIR}/test.cpp)

    # Add compile definitions
    target_compile_definitions(icu_test PRIVATE U_STATIC_IMPLEMENTATION)
    target_compile_definitions(icu_test PRIVATE ICU_ROOT="${ICU_ROOT}")

    # Find ICU libraries
    file(GLOB ICU_LIBS "${ICU_ROOT}/lib/*.lib")

    # Link ICU libraries
    target_link_libraries(icu_test ${ICU_LIBS} advapi32)
endif()
