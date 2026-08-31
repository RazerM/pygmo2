vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO coin-or/Ipopt
    REF ec43e37a06054246764fb116e50e3e30c9ada089
    SHA512 f5b30e81b4a1a178e9a0e2b51b4832f07441b2c3e9a2aa61a6f07807f94185998e985fcf3c34d96fbfde78f07b69f2e0a0675e1e478a4e668da6da60521e0fd6
    HEAD_REF master
)
  # --with-precision        floating-point precision to use: single or double
                          # (default)
  # --with-intsize          integer type to use: specify 32 for int or 64 for
                          # int64_t
file(COPY "${CURRENT_INSTALLED_DIR}/share/coin-or-buildtools/" DESTINATION "${SOURCE_PATH}")

set(ENV{ACLOCAL} "aclocal -I \"${SOURCE_PATH}/BuildTools\"")

# Ipopt needs a sparse linear solver for the KKT system; LAPACK alone is dense
# only and leaves the solver unusable at run time. MUMPS is the only sparse
# solver Ipopt supports that is redistributable, so it is on by default.
set(mumps_options "--without-mumps")
set(mumps_options_release "")
set(mumps_options_debug "")
if("mumps" IN_LIST FEATURES)
    # Bypass pkg-config, which would look for coin-or's own "coinmumps" module.
    set(fortran_runtime "")
    if(NOT VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_MINGW)
        set(fortran_runtime " -lgfortran -lm")
    endif()
    set(mumps_libs "-ldmumps -lmumps_common -lpord -lmpiseq_fortran -lmpiseq_c")
    set(mumps_options
        "--with-mumps"
        # IpMumpsSolverInterface.cpp includes mpi.h, which the mumps port installs
        # into the mumps_seq subdirectory to keep it away from real MPI headers.
        "--with-mumps-cflags=-I${CURRENT_INSTALLED_DIR}/include -I${CURRENT_INSTALLED_DIR}/include/mumps_seq"
    )
    set(mumps_options_release
        "--with-mumps-lflags=-L${CURRENT_INSTALLED_DIR}/lib ${mumps_libs}${fortran_runtime}"
    )
    set(mumps_options_debug
        "--with-mumps-lflags=-L${CURRENT_INSTALLED_DIR}/debug/lib ${mumps_libs}${fortran_runtime}"
    )
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTORECONF
    OPTIONS
      #--with-pardiso
      --without-spral
      #--without-wsmp
      --without-hsl
      --without-asl
      --with-lapack
      ${mumps_options}
      --enable-relocatable
      --disable-f77
      --disable-java
    OPTIONS_RELEASE
      ${mumps_options_release}
    OPTIONS_DEBUG
      ${mumps_options_debug}
)

vcpkg_make_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
