cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set bitness for this platform
set(BITNESS 64)

# Set platform-specific ICU directory
set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)

# Windows-specific settings
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
add_compile_definitions(NOMINMAX) # Avoid Windows min/max macros

# Use static libraries for Windows
set(BUILD_SHARED_LIBS OFF)

# Include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    message(FATAL_ERROR "Could not find common CMakeLists.txt")
endif()
