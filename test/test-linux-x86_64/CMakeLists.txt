cmake_minimum_required(VERSION 3.10)
project(ICU_Test)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set ICU directory
set(ICU_DIR ${CMAKE_SOURCE_DIR}/icu)

# Enable ICU examples now that we have a newer Ubuntu version
option(ENABLE_ICU_EXAMPLES "Enable ICU examples" ON)

# Check if ICU headers exist
if(EXISTS "${ICU_DIR}/include/unicode/uversion.h" AND
   EXISTS "${ICU_DIR}/include/unicode/unistr.h")
    message(STATUS "ICU headers found.")
    set(ICU_HEADERS_FOUND TRUE)
else()
    message(STATUS "ICU headers not found.")
    set(ICU_HEADERS_FOUND FALSE)
endif()

# Create executable
add_executable(icu_test test.cpp)

# Include ICU headers and link libraries if examples are enabled
if(ENABLE_ICU_EXAMPLES AND ICU_HEADERS_FOUND)
    # Include ICU headers
    include_directories(${ICU_DIR}/include)
    
    # Add necessary compiler flags for static ICU
    target_compile_definitions(icu_test PRIVATE
        U_STATIC_IMPLEMENTATION
        RUN_ICU_EXAMPLES
    )
    
    # Add compiler flags to handle C23 compatibility issues
    target_compile_options(icu_test PRIVATE
        -D_GNU_SOURCE
        -fPIC
    )
    
    # Use a simpler approach for linking ICU libraries
    # First link the system libraries that ICU depends on
    target_link_libraries(icu_test pthread dl m stdc++)
    
    # Then link the ICU libraries in the correct order
    target_link_libraries(icu_test
        -Wl,--whole-archive
        ${ICU_DIR}/lib/libicudata.a
        -Wl,--no-whole-archive
        ${ICU_DIR}/lib/libicui18n.a
        ${ICU_DIR}/lib/libicuuc.a
        ${ICU_DIR}/lib/libicuio.a)
    
    message(STATUS "ICU examples enabled")
    message(STATUS "Found ICU libraries: ${ICU_LIBS}")
else()
    message(STATUS "ICU examples disabled")
endif()

# Print ICU directory for debugging
message(STATUS "ICU directory: ${ICU_DIR}")
