#!/usr/bin/env bash

# Install what the vcpkg dependencies need on a macOS runner.
#
# coin-or-ipopt and mumps build with autotools, and autoconf-archive in
# particular is not on the images. MUMPS is Fortran, and the images carry no
# gfortran on PATH at all, so one has to be installed.

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

if ! command -v gfortran > /dev/null; then
    prefix="$(brew --prefix)"
    # Prefer a versioned gfortran the image may already carry over installing
    # the whole gcc formula, which is a slow bottle to pour.
    newest="$(ls "${prefix}"/bin/gfortran-* 2> /dev/null | sort -V | tail -1 || true)"
    if [[ -n "${newest}" ]]; then
        ln -sf "${newest}" "${prefix}/bin/gfortran"
    else
        brew install gcc
    fi
fi
gfortran --version

set +x
