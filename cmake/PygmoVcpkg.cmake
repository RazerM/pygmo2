include_guard(GLOBAL)

# Fetch, bootstrap and activate vcpkg. Included before project(), the last point
# at which CMAKE_TOOLCHAIN_FILE can be set.

# A caller who passes vcpkg's own toolchain brings their own vcpkg. Chainloading
# it is not an option: vcpkg's toolchain includes the chainloaded file before its
# re-entry guard, so the caller's vcpkg would run in place of the pinned one.
if(CMAKE_TOOLCHAIN_FILE MATCHES "[/\\\\]scripts[/\\\\]buildsystems[/\\\\]vcpkg\\.cmake$"
   AND NOT CMAKE_TOOLCHAIN_FILE STREQUAL "$CACHE{_PYGMO_VCPKG_TOOLCHAIN}")
    message(STATUS "Using the vcpkg toolchain passed in: ${CMAKE_TOOLCHAIN_FILE}")
    return()
endif()

include(FetchContent)
# vcpkg.json's builtin-baseline has to name this tag's commit: the shallow clone
# holds no other.
FetchContent_Declare(vcpkg
    GIT_REPOSITORY "https://github.com/microsoft/vcpkg.git"
    GIT_TAG "2026.10.16"
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(vcpkg)

if(CMAKE_HOST_WIN32)
    set(_pygmo_vcpkg_exe "${vcpkg_SOURCE_DIR}/vcpkg.exe")
    set(_pygmo_vcpkg_bootstrap "${vcpkg_SOURCE_DIR}/bootstrap-vcpkg.bat")
else()
    set(_pygmo_vcpkg_exe "${vcpkg_SOURCE_DIR}/vcpkg")
    set(_pygmo_vcpkg_bootstrap "${vcpkg_SOURCE_DIR}/bootstrap-vcpkg.sh")
endif()
# vcpkg's toolchain would bootstrap too, but it only writes the output to a log
# file, which pip deletes when an install from an sdist fails. vcpkg pins its
# tool's version in the stamp file, so a newer stamp means a stale tool.
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
unset(_pygmo_vcpkg_exe)
unset(_pygmo_vcpkg_bootstrap)
unset(_pygmo_vcpkg_stamp)
unset(_pygmo_vcpkg_bootstrap_result)

# vcpkg's toolchain also runs a toolchain file the caller passed, given as
# VCPKG_CHAINLOAD_TOOLCHAIN_FILE. Never give it vcpkg's own: it includes that
# file before its re-entry guard, so a reconfigure would recurse until CMake
# gives up.
if(CMAKE_TOOLCHAIN_FILE AND NOT CMAKE_TOOLCHAIN_FILE STREQUAL "$CACHE{_PYGMO_VCPKG_TOOLCHAIN}")
    set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_TOOLCHAIN_FILE}" CACHE FILEPATH
        "Toolchain file chainloaded by the vcpkg toolchain." FORCE)
endif()
set(_PYGMO_VCPKG_TOOLCHAIN "${vcpkg_SOURCE_DIR}/scripts/buildsystems/vcpkg.cmake" CACHE INTERNAL "")
set(CMAKE_TOOLCHAIN_FILE "${_PYGMO_VCPKG_TOOLCHAIN}" CACHE FILEPATH "Toolchain file." FORCE)
