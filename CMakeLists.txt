cmake_minimum_required(VERSION 3.16)
project(vsavsreader
    VERSION 2.0.0
    DESCRIPTION "AviSynth Script Reader plugin for VapourSynth"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Dependencies ────────────────────────────────────────────────────
# Vendored headers: VapourSynth4.h + AviSynth+ SDK
set(VENDOR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor")
set(VAPOURSYNTH_VENDOR_DIR "${VENDOR_DIR}/vapoursynth")
set(AVISYNTH_VENDOR_DIR "${VENDOR_DIR}/avisynth")

# Attempt pkg-config only as fallback for the shared library linkage
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(VAPOURSYNTH vapoursynth-script)
endif()

if(NOT VAPOURSYNTH_FOUND)
    find_path(VAPOURSYNTH_INCLUDE_DIR
        NAMES VapourSynth4.h
        PATHS
            /usr/include
            /usr/local/include
            /opt/homebrew/include
            /usr/include/vapoursynth
            /usr/local/include/vapoursynth
            "C:/Program Files/VapourSynth/include"
            "C:/Program Files (x86)/VapourSynth/include"
        NO_DEFAULT_PATH
    )
    find_path(VAPOURSYNTH_LIBRARY_DIR
        NAMES vapoursynth.lib libvapoursynth.dylib libvapoursynth.so
        PATHS
            /usr/lib
            /usr/local/lib
            /opt/homebrew/lib
            "C:/Program Files/VapourSynth/lib"
            "C:/Program Files (x86)/VapourSynth/lib"
        NO_DEFAULT_PATH
    )
    if(VAPOURSYNTH_INCLUDE_DIR)
        set(VAPOURSYNTH_INCLUDE_DIRS "${VAPOURSYNTH_INCLUDE_DIR}")
    endif()
endif()

# ── Sources ─────────────────────────────────────────────────────────
set(SOURCES
    src/AvsReader.cpp
    src/plugin.cpp
)

# ── AviSynth+ runtime link (macOS/Linux) ────────────────────────────
# On Windows the plugin loads avisynth.dll dynamically via LoadLibrary.
# On macOS/Linux we dlopen() libavisynth at runtime, but we can also
# detect the system install so the build knows AviSynth+ is available.
if(PkgConfig_FOUND)
    pkg_check_modules(AVISYNTH_PC avisynth)
endif()

# ── Shared library ──────────────────────────────────────────────────
add_library(vsavsreader SHARED ${SOURCES})

target_include_directories(vsavsreader PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src           # for "AvsReader.h", "myvshelper.h"
    ${VAPOURSYNTH_VENDOR_DIR}             # vendored VapourSynth4.h
    ${AVISYNTH_PC_INCLUDE_DIRS}           # system AviSynth+ headers (match runtime)
    ${AVISYNTH_VENDOR_DIR}                # vendored fallback avisynth.h + avs/*.h
    ${VAPOURSYNTH_INCLUDE_DIRS}           # system fallback (if any)
)

if(WIN32)
    target_compile_definitions(vsavsreader PRIVATE _WIN32)
    if(VAPOURSYNTH_LIBRARY_DIR)
        find_library(VAPOURSYNTH_LIB vapoursynth HINTS ${VAPOURSYNTH_LIBRARY_DIR})
        if(VAPOURSYNTH_LIB)
            target_link_libraries(vsavsreader PRIVATE ${VAPOURSYNTH_LIB})
        endif()
    endif()
else()
    target_compile_definitions(vsavsreader PRIVATE _POSIX)
    if(AVISYNTH_PC_FOUND)
        target_compile_definitions(vsavsreader PRIVATE
            HAVE_AVISYNTH=1
            AVISYNTH_LIB_DIR="${AVISYNTH_PC_LIBRARY_DIRS}")
        target_include_directories(vsavsreader PRIVATE ${AVISYNTH_PC_INCLUDE_DIRS})
        set_target_properties(vsavsreader PROPERTIES
            INSTALL_RPATH "${AVISYNTH_PC_LIBRARY_DIRS};$ORIGIN")
    endif()
    if(APPLE)
        target_link_libraries(vsavsreader PRIVATE
            ${VAPOURSYNTH_LIBRARIES}
            "-framework CoreFoundation")
        set_target_properties(vsavsreader PROPERTIES
            SUFFIX ".dylib" PREFIX ""
            INSTALL_RPATH "@loader_path;${VAPOURSYNTH_LIBRARY_DIRS}")
    else()
        target_link_libraries(vsavsreader PRIVATE ${VAPOURSYNTH_LIBRARIES})
        set_target_properties(vsavsreader PROPERTIES
            SUFFIX ".so" PREFIX ""
            INSTALL_RPATH "$ORIGIN;${VAPOURSYNTH_LIBRARY_DIRS}")
    endif()
endif()

set_target_properties(vsavsreader PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    POSITION_INDEPENDENT_CODE ON
)

# ── Install ─────────────────────────────────────────────────────────
install(TARGETS vsavsreader
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
