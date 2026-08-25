include_guard(GLOBAL)

# Fetch, bootstrap and activate vcpkg, so that the C++ libraries pygmo needs
# are built from source rather than expected on the system. Included from the
# top-level CMakeLists.txt before project(), which is the last point at which
# CMAKE_TOOLCHAIN_FILE can still be set.

# NOTE: PYGMO_VCPKG_REF and the builtin-baseline in vcpkg.json pin the same
# vcpkg checkout and have to be bumped together.
set(PYGMO_VCPKG_REPOSITORY "https://github.com/microsoft/vcpkg.git" CACHE STRING
    "Repository to fetch vcpkg from.")
set(PYGMO_VCPKG_REF "2026.07.29" CACHE STRING
    "Tag of the vcpkg release to fetch.")
mark_as_advanced(PYGMO_VCPKG_REPOSITORY PYGMO_VCPKG_REF)

include(FetchContent)
FetchContent_Declare(vcpkg
    GIT_REPOSITORY "${PYGMO_VCPKG_REPOSITORY}"
    GIT_TAG "${PYGMO_VCPKG_REF}"
    GIT_SHALLOW TRUE
    # vcpkg is not a CMake project: point SOURCE_SUBDIR at a path that does not
    # exist, so that MakeAvailable populates it without add_subdirectory().
    SOURCE_SUBDIR "not-a-cmake-project"
)
FetchContent_MakeAvailable(vcpkg)

if(WIN32)
    set(_pygmo_vcpkg_exe "${vcpkg_SOURCE_DIR}/vcpkg.exe")
    set(_pygmo_vcpkg_bootstrap "${vcpkg_SOURCE_DIR}/bootstrap-vcpkg.bat")
else()
    set(_pygmo_vcpkg_exe "${vcpkg_SOURCE_DIR}/vcpkg")
    set(_pygmo_vcpkg_bootstrap "${vcpkg_SOURCE_DIR}/bootstrap-vcpkg.sh")
endif()

# GIT_SHALLOW gives a depth-1 checkout of the tag, so vcpkg.json's
# builtin-baseline is only resolvable while it names that same commit. Check it
# here rather than letting vcpkg fail later from inside version resolution.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg.json" _pygmo_manifest)
string(JSON _pygmo_baseline ERROR_VARIABLE _pygmo_baseline_error
    GET "${_pygmo_manifest}" "builtin-baseline")
if(_pygmo_baseline AND NOT _pygmo_baseline_error)
    find_package(Git QUIET REQUIRED)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" cat-file -e "${_pygmo_baseline}^{commit}"
        WORKING_DIRECTORY "${vcpkg_SOURCE_DIR}"
        RESULT_VARIABLE _pygmo_baseline_result
        OUTPUT_QUIET ERROR_QUIET
    )
    if(NOT _pygmo_baseline_result STREQUAL "0")
        message(FATAL_ERROR
            "vcpkg.json's builtin-baseline (${_pygmo_baseline}) is not present in the vcpkg "
            "checkout at PYGMO_VCPKG_REF=${PYGMO_VCPKG_REF}. They pin the same commit and have "
            "to be bumped together.")
    endif()
endif()
unset(_pygmo_manifest)
unset(_pygmo_baseline)
unset(_pygmo_baseline_error)
unset(_pygmo_baseline_result)

# vcpkg pins the version of its own tool in this file, so it doubles as a
# staleness stamp: EXISTS alone would keep a tool bootstrapped for an older
# PYGMO_VCPKG_REF and fail much later with "vcpkg-tool is out of date".
set(_pygmo_vcpkg_stamp "${vcpkg_SOURCE_DIR}/scripts/vcpkg-tool-metadata.txt")
if(NOT EXISTS "${_pygmo_vcpkg_exe}" OR "${_pygmo_vcpkg_stamp}" IS_NEWER_THAN "${_pygmo_vcpkg_exe}")
    message(STATUS "Bootstrapping vcpkg in ${vcpkg_SOURCE_DIR}")
    execute_process(
        COMMAND "${_pygmo_vcpkg_bootstrap}" -disableMetrics
        WORKING_DIRECTORY "${vcpkg_SOURCE_DIR}"
        RESULT_VARIABLE _pygmo_vcpkg_bootstrap_result
    )
    # RESULT_VARIABLE holds a message rather than a number when the process
    # cannot be started at all, so compare as a string.
    if(NOT _pygmo_vcpkg_bootstrap_result STREQUAL "0")
        message(FATAL_ERROR
            "Failed to bootstrap vcpkg (${_pygmo_vcpkg_bootstrap_result}). See the output above.")
    endif()
endif()

# Keep honouring a toolchain file the caller passed in, but never chainload
# vcpkg's own toolchain onto itself: it includes the chainloaded file before
# its re-entry guard, so on the second configure of a build tree that recurses
# until CMake gives up.
set(_pygmo_vcpkg_toolchain "${vcpkg_SOURCE_DIR}/scripts/buildsystems/vcpkg.cmake")
if(CMAKE_TOOLCHAIN_FILE)
    file(REAL_PATH "${CMAKE_TOOLCHAIN_FILE}" _pygmo_prev_toolchain
        BASE_DIRECTORY "${CMAKE_BINARY_DIR}")
    file(REAL_PATH "${_pygmo_vcpkg_toolchain}" _pygmo_own_toolchain)
    if(NOT _pygmo_prev_toolchain STREQUAL _pygmo_own_toolchain)
        set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${_pygmo_prev_toolchain}" CACHE FILEPATH
            "Toolchain file chainloaded by the vcpkg toolchain." FORCE)
    endif()
endif()
set(CMAKE_TOOLCHAIN_FILE "${_pygmo_vcpkg_toolchain}" CACHE FILEPATH "Toolchain file." FORCE)

unset(_pygmo_vcpkg_exe)
unset(_pygmo_vcpkg_bootstrap)
unset(_pygmo_vcpkg_bootstrap_result)
unset(_pygmo_vcpkg_stamp)
unset(_pygmo_vcpkg_toolchain)
unset(_pygmo_prev_toolchain)
unset(_pygmo_own_toolchain)
