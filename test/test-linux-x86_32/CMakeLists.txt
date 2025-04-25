cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set platform-specific ICU directory
set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)

# Additional Linux 32-bit specific settings
set(BUILD_SHARED_LIBS OFF)  # Use static libraries for Linux
add_compile_options(-m32)   # Force 32-bit compilation
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")

# Include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    message(FATAL_ERROR "Could not find common CMakeLists.txt")
endif()
