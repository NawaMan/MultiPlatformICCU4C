# Common CMakeLists.txt for ICU4C tests
cmake_minimum_required(VERSION 3.14)
project(icu4c_test)

# Set ICU version
set(ICU4C_VERSION 77.1)

# Set C++ standard - using C++23 for modern features
set(CMAKE_CXX_STANDARD          23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Ensure proper handling of different platforms
if(WIN32)
    # Windows-specific settings
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_compile_definitions(NOMINMAX) # Avoid Windows min/max macros
elseif(APPLE)
    # macOS-specific settings
    set(CMAKE_MACOSX_RPATH ON)
elseif(UNIX)
    # Linux-specific settings
    add_compile_options(-fPIC)
endif()

# Default ICU root path if not specified
if(NOT DEFINED ICU_ROOT)
    if(DEFINED ENV{ICU_ROOT})
        set(ICU_ROOT $ENV{ICU_ROOT})
    else()
        # Platform-specific defaults
        if(WIN32)
            set(ICU_ROOT "C:/icu")
        elseif(APPLE)
            set(ICU_ROOT "/usr/local/opt/icu4c")
        else()
            set(ICU_ROOT "/app/icu")
        endif()
    endif()
endif()

# ICU data directory for modular data files
if(NOT DEFINED ICU_DATA_DIR)
    if(DEFINED ENV{ICU_DATA})
        set(ICU_DATA_DIR $ENV{ICU_DATA})
    else()
        # Check common locations for the ICU data file
        if(EXISTS "${ICU_ROOT}/share/icu/${ICU4C_VERSION}/icudt${ICU4C_VERSION%%.*}l.dat")
            set(ICU_DATA_DIR "${ICU_ROOT}/share/icu/${ICU4C_VERSION}")
        elseif(EXISTS "${ICU_ROOT}/share/icu/current/icudt${ICU4C_VERSION%%.*}l.dat")
            set(ICU_DATA_DIR "${ICU_ROOT}/share/icu/current")
        elseif(EXISTS "${ICU_ROOT}/data/icudt${ICU4C_VERSION%%.*}l.dat")
            set(ICU_DATA_DIR "${ICU_ROOT}/data")
        else()
            # Default to a subdirectory of ICU_ROOT
            set(ICU_DATA_DIR "${ICU_ROOT}/data")
        endif()
    endif()
endif()

message(STATUS "ICU data directory: ${ICU_DATA_DIR}")

message(STATUS "ICU directory: ${ICU_ROOT}")

# Find ICU headers
if(EXISTS "${ICU_ROOT}/include/unicode/uversion.h")
    message(STATUS "ICU headers found.")
    include_directories(${ICU_ROOT}/include)
else()
    message(FATAL_ERROR "ICU headers not found at ${ICU_ROOT}/include")
endif()

# Find ICU libraries
set(ICU_LIBRARIES "")
set(ICU_REQUIRED_LIBS icuuc icudata icui18n icuio)

# Try to find libraries in multiple formats to support different ICU installations
foreach(lib ${ICU_REQUIRED_LIBS})
    # Define potential library names/paths based on platform
    set(lib_candidates "")
    
    if(WIN32)
        # Windows has multiple possible formats
        list(APPEND lib_candidates "${ICU_ROOT}/lib/${lib}.lib")
        list(APPEND lib_candidates "${ICU_ROOT}/lib/${lib}d.lib") # Debug version
        list(APPEND lib_candidates "${ICU_ROOT}/lib/sicu${lib}.lib") # Static version
    elseif(APPLE)
        # macOS has both dylib and a formats
        list(APPEND lib_candidates "${ICU_ROOT}/lib/lib${lib}.dylib")
        list(APPEND lib_candidates "${ICU_ROOT}/lib/lib${lib}.a")
        # Homebrew/MacPorts potential locations
        list(APPEND lib_candidates "/usr/local/opt/icu4c/lib/lib${lib}.dylib")
        list(APPEND lib_candidates "/opt/local/lib/lib${lib}.dylib")
    else()
        # Linux has both .so and .a formats
        list(APPEND lib_candidates "${ICU_ROOT}/lib/lib${lib}.a")
        list(APPEND lib_candidates "${ICU_ROOT}/lib/lib${lib}.so")
        # System locations
        list(APPEND lib_candidates "/usr/lib/lib${lib}.so")
        list(APPEND lib_candidates "/usr/lib/x86_64-linux-gnu/lib${lib}.so")
    endif()
    
    # Try to find the library in the candidate locations
    set(lib_found FALSE)
    foreach(candidate ${lib_candidates})
        if(EXISTS ${candidate})
            list(APPEND ICU_LIBRARIES ${candidate})
            set(lib_found TRUE)
            message(STATUS "Found ${lib}: ${candidate}")
            break()
        endif()
    endforeach()
    
    if(NOT lib_found)
        message(WARNING "ICU library not found: ${lib}")
    endif()
endforeach()

message(STATUS "Found ICU libraries: ${ICU_LIBRARIES}")

# Option to enable ICU examples
option(ENABLE_ICU_EXAMPLES "Enable ICU examples" ON)
if(ENABLE_ICU_EXAMPLES)
    add_definitions(-DRUN_ICU_EXAMPLES)
    message(STATUS "ICU examples enabled")
else()
    message(STATUS "ICU examples disabled")
endif()

# Add ICU data directory definition
if(EXISTS "${ICU_DATA_DIR}")
    # Check if the data file exists in the directory
    file(GLOB ICU_DATA_FILES "${ICU_DATA_DIR}/icudt*l.dat")
    if(ICU_DATA_FILES)
        add_definitions(-DICU_DATA_DIR="${ICU_DATA_DIR}")
        message(STATUS "ICU data file found in: ${ICU_DATA_DIR}")
    else()
        message(WARNING "No ICU data file found in ${ICU_DATA_DIR}, looking in other locations")
        # Try to find the data file in other common locations
        if(EXISTS "${ICU_ROOT}/share/icu/77.1/icudt77l.dat")
            set(ICU_DATA_DIR "${ICU_ROOT}/share/icu/77.1")
            add_definitions(-DICU_DATA_DIR="${ICU_DATA_DIR}")
            message(STATUS "ICU data file found in: ${ICU_DATA_DIR}")
        endif()
    endif()
endif()

# Add the test executable
add_executable(icu_test ${CMAKE_CURRENT_SOURCE_DIR}/test.cpp)

# Add compile definitions for ICU_ROOT
target_compile_definitions(icu_test PRIVATE ICU_ROOT="${ICU_ROOT}")

# Add U_STATIC_IMPLEMENTATION for static builds
if(NOT BUILD_SHARED_LIBS)
    target_compile_definitions(icu_test PRIVATE U_STATIC_IMPLEMENTATION)
endif()

# Link against ICU libraries
# Check if we have a custom ICU linking function (from toolchain)
if(COMMAND target_link_icu)
    # Use the custom function for proper linking order and flags
    target_link_icu(icu_test)
else()
    # Fall back to standard linking
    target_link_libraries(icu_test ${ICU_LIBRARIES})
endif()

# Add platform-specific libraries and settings
if(WIN32)
    # Windows-specific libraries
    target_link_libraries(icu_test advapi32)
    # Use static runtime on Windows if building static libraries
    if(NOT BUILD_SHARED_LIBS)
        set_property(TARGET icu_test PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
elseif(APPLE)
    # macOS-specific settings
    target_link_libraries(icu_test "${CMAKE_DL_LIBS}")
    # Add macOS frameworks if needed
    # target_link_libraries(icu_test "-framework CoreFoundation")
elseif(UNIX)
    # Linux-specific libraries
    target_link_libraries(icu_test dl pthread m)
endif()

# Add installation rules
install(TARGETS icu_test
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib)

# Create a test target
add_custom_target(run_test
    COMMAND icu_test
    DEPENDS icu_test
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running ICU4C tests..."
)
