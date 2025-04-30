cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set bitness for this platform
set(BITNESS 64)

# Set platform-specific ICU directory
set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)

# Additional Linux-specific settings (if needed)
set(BUILD_SHARED_LIBS OFF)  # Use static libraries for Linux
add_compile_options(-m${BITNESS})
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m${BITNESS}")
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   -m${BITNESS}")

# Include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    message(FATAL_ERROR "Could not find common CMakeLists.txt")
endif()
