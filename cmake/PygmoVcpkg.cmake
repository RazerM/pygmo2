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

# Windows limits paths to 260 characters and pip builds deep inside a temporary
# directory, so put vcpkg's buildtrees and packages under a short directory in
# TEMP instead, keyed on the build tree. vcpkg's toolchain caches
# VCPKG_INSTALL_OPTIONS, so a reconfigure finds them already there.
if(CMAKE_HOST_WIN32 AND DEFINED ENV{TEMP}
   AND NOT VCPKG_INSTALL_OPTIONS MATCHES "--x-(buildtrees|packages)-root")
    string(SHA1 _pygmo_vcpkg_key "${CMAKE_BINARY_DIR}")
    string(SUBSTRING "${_pygmo_vcpkg_key}" 0 8 _pygmo_vcpkg_key)
    string(REPLACE "\\" "/" _pygmo_vcpkg_scratch "$ENV{TEMP}/pygmo-vcpkg/${_pygmo_vcpkg_key}")
    set(VCPKG_INSTALL_OPTIONS ${VCPKG_INSTALL_OPTIONS}
        "--x-buildtrees-root=${_pygmo_vcpkg_scratch}/b"
        "--x-packages-root=${_pygmo_vcpkg_scratch}/p"
        --clean-buildtrees-after-build --clean-packages-after-build)
    unset(_pygmo_vcpkg_key)
    unset(_pygmo_vcpkg_scratch)
endif()

# vcpkg's default Linux and macOS triplets link the dependencies statically,
# which oneTBB does not support. Platforms without a dynamic triplet keep the
# default.
if(NOT CMAKE_HOST_WIN32 AND NOT VCPKG_TARGET_TRIPLET)
    cmake_host_system_information(RESULT _pygmo_arch QUERY OS_PLATFORM)
    if(CMAKE_OSX_ARCHITECTURES)
        set(_pygmo_arch "${CMAKE_OSX_ARCHITECTURES}")
    endif()
    if(_pygmo_arch MATCHES "^(x86_64|amd64)$")
        set(_pygmo_arch x64)
    elseif(_pygmo_arch MATCHES "^(aarch64|arm64)$")
        set(_pygmo_arch arm64)
    endif()
    cmake_host_system_information(RESULT _pygmo_os QUERY OS_NAME)
    if(_pygmo_os STREQUAL "Linux")
        set(_pygmo_os linux)
    elseif(_pygmo_os STREQUAL "macOS")
        set(_pygmo_os osx)
    endif()
    if(EXISTS "${vcpkg_SOURCE_DIR}/triplets/community/${_pygmo_arch}-${_pygmo_os}-dynamic.cmake")
        set(VCPKG_TARGET_TRIPLET "${_pygmo_arch}-${_pygmo_os}-dynamic" CACHE STRING
            "vcpkg triplet to build the dependencies for.")
    endif()
    unset(_pygmo_arch)
    unset(_pygmo_os)
endif()

# vcpkg builds a debug and a release copy of every dependency, and pygmo only
# uses the release one. Only a triplet can switch that off (VCPKG_BUILD_TYPE),
# so shadow each built-in triplet with a copy that does. Overlays the caller
# passes take precedence.
set(_pygmo_triplet_dir "${CMAKE_BINARY_DIR}/pygmo-vcpkg-triplets")
# vcpkg's toolchain caches VCPKG_OVERLAY_TRIPLETS, so drop our entry from a
# previous configure first, or turning the option off would have no effect.
list(REMOVE_ITEM VCPKG_OVERLAY_TRIPLETS "${_pygmo_triplet_dir}")
if(PYGMO_VCPKG_RELEASE_ONLY)
    file(MAKE_DIRECTORY "${_pygmo_triplet_dir}")
    file(GLOB _pygmo_triplets
        "${vcpkg_SOURCE_DIR}/triplets/*.cmake"
        "${vcpkg_SOURCE_DIR}/triplets/community/*.cmake")
    foreach(_pygmo_triplet IN LISTS _pygmo_triplets)
        get_filename_component(_pygmo_triplet_name "${_pygmo_triplet}" NAME)
        file(READ "${_pygmo_triplet}" _pygmo_triplet_body)
        string(APPEND _pygmo_triplet_body "\nset(VCPKG_BUILD_TYPE release)\n")
        set(_pygmo_triplet_out "${_pygmo_triplet_dir}/${_pygmo_triplet_name}")
        # Only write on change: this runs over every built-in triplet on every
        # configure, and rewriting them would churn their mtimes.
        set(_pygmo_triplet_old "")
        if(EXISTS "${_pygmo_triplet_out}")
            file(READ "${_pygmo_triplet_out}" _pygmo_triplet_old)
        endif()
        if(NOT _pygmo_triplet_old STREQUAL _pygmo_triplet_body)
            file(WRITE "${_pygmo_triplet_out}" "${_pygmo_triplet_body}")
        endif()
    endforeach()
    list(APPEND VCPKG_OVERLAY_TRIPLETS "${_pygmo_triplet_dir}")
    unset(_pygmo_triplets)
    unset(_pygmo_triplet)
    unset(_pygmo_triplet_name)
    unset(_pygmo_triplet_body)
    unset(_pygmo_triplet_out)
    unset(_pygmo_triplet_old)
endif()
unset(_pygmo_triplet_dir)

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
