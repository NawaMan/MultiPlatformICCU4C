cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set platform-specific ICU directory
set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)

# WebAssembly-specific settings
set(BUILD_SHARED_LIBS OFF)  # Use static libraries for WASM
set(CMAKE_EXECUTABLE_SUFFIX ".html")  # Output as HTML for browser testing

# Preload ICU data files for WASM
option(PRELOAD_ICU "Preload ICU data files for WASM" ON)
if(PRELOAD_ICU)
    # Add preload flags for ICU files
    set(ICU_PRELOAD_FILES "${ICU_ROOT}/lib/libicuuc.a" "${ICU_ROOT}/lib/libicudata.a" "${ICU_ROOT}/lib/libicui18n.a" "${ICU_ROOT}/lib/libicuio.a")
    set(ICU_INCLUDE_DIR "${ICU_ROOT}/include")
    
    # Add preload-file flags for each ICU file
    foreach(ICU_FILE ${ICU_PRELOAD_FILES})
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --preload-file ${ICU_FILE}@/app/icu/lib/")
    endforeach()
    
    # Preload header files
    file(GLOB ICU_HEADERS "${ICU_INCLUDE_DIR}/unicode/*.h")
    foreach(HEADER ${ICU_HEADERS})
        get_filename_component(HEADER_NAME ${HEADER} NAME)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --preload-file ${HEADER}@/app/icu/include/unicode/${HEADER_NAME}")
    endforeach()
    
    # Add define to indicate preloaded files
    add_definitions(-DICU_PRELOADED=1)
endif()

# Define WASM_ENVIRONMENT for the WASM-specific test
add_definitions(-DWASM_ENVIRONMENT=1)

# Add a define to indicate this is a 64-bit test
add_definitions(-DWASM_64BIT_TEST=1)

# Create a simple WASM64 test file to verify 64-bit memory capabilities
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/wasm64_test.cpp "
#include <iostream>
#include <vector>
#include <cstdint>

// Check if we're in WASM64 mode
#if defined(__wasm64__)
#define IS_WASM64 1
#else
#define IS_WASM64 0
#endif

int main() {
    std::cout << \"=== WebAssembly 64-bit Memory Test ===\" << std::endl;
    
    // Test 1: Check pointer size
    std::cout << \"Pointer size: \" << sizeof(void*) << \" bytes\" << std::endl;
    std::cout << \"Is WASM64 defined: \" << (IS_WASM64 ? \"Yes\" : \"No\") << std::endl;
    
    // Test 2: Try to allocate a large memory block (> 2GB)
    std::cout << \"Attempting to allocate large memory block...\" << std::endl;
    
    try {
        // Allocate 3GB of memory (well beyond 32-bit limit)
        size_t size = size_t(3) * 1024 * 1024 * 1024;  // 3GB
        std::vector<uint8_t> largeBlock(size);
        
        // Write to the beginning, middle, and end to ensure it's usable
        largeBlock[0] = 1;
        largeBlock[size/2] = 2;
        largeBlock[size-1] = 3;
        
        std::cout << \"Successfully allocated and accessed \" << (size / (1024.0 * 1024 * 1024)) << \"GB of memory!\" << std::endl;
        std::cout << \"Values: \" << (int)largeBlock[0] << \", \" << (int)largeBlock[size/2] << \", \" << (int)largeBlock[size-1] << std::endl;
    } catch (const std::exception& e) {
        std::cout << \"Failed to allocate large memory: \" << e.what() << std::endl;
        return 1;
    }
    
    std::cout << \"All tests passed!\" << std::endl;
    return 0;
}
")

# Add the WASM64 test executable
add_executable(wasm64_test ${CMAKE_CURRENT_BINARY_DIR}/wasm64_test.cpp)

# Enable 64-bit memory for the WASM64 test with large memory allocation
set_target_properties(wasm64_test PROPERTIES
    COMPILE_FLAGS "-sMEMORY64=1 -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=4GB"
    LINK_FLAGS "-sMEMORY64=1 -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=4GB")

# Include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    message(FATAL_ERROR "Could not find common CMakeLists.txt")
endif()
