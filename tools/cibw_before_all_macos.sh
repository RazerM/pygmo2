#!/usr/bin/env bash

# Install what the vcpkg dependencies need on a macOS runner.
#
# coin-or-ipopt and mumps build with autotools, and autoconf-archive in
# particular is not on the images.
#
# MUMPS is Fortran, and the Fortran runtime is the awkward part: delocate
# bundles whichever libgfortran the extension resolves against, then refuses to
# tag the wheel as supporting macOS older than that runtime does. Every
# gfortran on the images ships a runtime with a 14.0 minimum, which would drag
# every macOS wheel up from 11.0. conda-forge builds its toolchain against an
# older SDK, so take the compiler and the runtime from there: both come from
# the same build, which the image's compiler plus a borrowed runtime would not.

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

FORTRAN_PREFIX="${FORTRAN_PREFIX:-/opt/pygmo-fortran}"
arch="$(uname -m)"
case "${arch}" in
    arm64) subdir="osx-arm64" ;;
    x86_64) subdir="osx-64" ;;
    *) echo "unsupported arch ${arch}"; exit 1 ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
curl -Ls "https://micro.mamba.run/api/micromamba/${subdir}/latest" | tar -xj -C "${work}" bin/micromamba

sudo mkdir -p "${FORTRAN_PREFIX}"
sudo chown -R "$(id -un)" "${FORTRAN_PREFIX}"
"${work}/bin/micromamba" create -y -p "${FORTRAN_PREFIX}" -c conda-forge \
    "gfortran_${subdir}" libgfortran5

# conda-forge names the driver for its target triple; give it the plain name
# that CMake's Fortran detection looks for.
driver="$(find "${FORTRAN_PREFIX}/bin" -name "*-gfortran" | head -1)"
ln -sf "${driver}" "${FORTRAN_PREFIX}/bin/gfortran"
"${FORTRAN_PREFIX}/bin/gfortran" --version

for lib in libgfortran.5.dylib libquadmath.0.dylib; do
    f="${FORTRAN_PREFIX}/lib/${lib}"
    [[ -f "${f}" ]] &&
        echo "  ${lib} minos $(otool -l "${f}" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
done

set +x
