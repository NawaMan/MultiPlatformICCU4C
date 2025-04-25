cmake_minimum_required(VERSION 3.14)
project(ICU_Test)

# Set platform-specific ICU directory
set(ICU_ROOT ${CMAKE_SOURCE_DIR}/icu)

# WebAssembly-specific settings
set(BUILD_SHARED_LIBS OFF)  # Use static libraries for WASM
set(CMAKE_EXECUTABLE_SUFFIX ".html")  # Output as HTML for browser testing

# Preload ICU data files for WASM
option(PRELOAD_ICU "Preload ICU data files for WASM" OFF)
if(PRELOAD_ICU)
    # Add preload flags for ICU files
    set(ICU_PRELOAD_FILES "${ICU_ROOT}/lib/libicuuc.a" "${ICU_ROOT}/lib/libicudata.a" "${ICU_ROOT}/lib/libicui18n.a" "${ICU_ROOT}/lib/libicuio.a")
    set(ICU_INCLUDE_DIR "${ICU_ROOT}/include/unicode")
    
    # Add preload-file flags for each ICU file
    foreach(ICU_FILE ${ICU_PRELOAD_FILES})
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --preload-file ${ICU_FILE}@/app/icu/lib/")
    endforeach()
    
    # Preload header files
    file(GLOB ICU_HEADERS "${ICU_INCLUDE_DIR}/*.h")
    foreach(HEADER ${ICU_HEADERS})
        get_filename_component(HEADER_NAME ${HEADER} NAME)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --preload-file ${HEADER}@/app/icu/include/unicode/${HEADER_NAME}")
    endforeach()
    
    # Add define to indicate preloaded files
    add_definitions(-DICU_PRELOADED=1)
endif()

# Define WASM_ENVIRONMENT for the WASM-specific test
add_definitions(-DWASM_ENVIRONMENT=1)

# Include the shared CMakeLists.txt from the parent directory
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt")
    include(${CMAKE_CURRENT_SOURCE_DIR}/../CMakeLists.txt)
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common")
    include(${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.txt.common)
else()
    message(FATAL_ERROR "Could not find common CMakeLists.txt")
endif()
