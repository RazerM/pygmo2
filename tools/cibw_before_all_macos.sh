#!/usr/bin/env bash

# Install what the vcpkg dependencies need on a macOS runner.
#
# coin-or-ipopt and mumps build with autotools, and autoconf-archive in
# particular is not on the images.
#
# MUMPS is Fortran, and the runtime is the awkward part: delocate bundles
# whichever libgfortran the extension resolves against, then refuses to tag the
# wheel as supporting macOS older than that runtime does. Every gfortran on the
# images ships a runtime with a 14.0 minimum, which would drag every macOS
# wheel up from 11.0.
#
# So use the toolchain numpy and scipy have built their macOS wheels with for
# years, from isuruf/gcc: compiler and runtime come from the same build, and
# the runtime targets 11.0. Note that the gcc-15.2.0 release is unusable --
# its libgfortran.spec is a symlink to the release author's own build prefix,
# so every link fails with "cannot read spec file".

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

GFORTRAN_RELEASE="${GFORTRAN_RELEASE:-gcc-11.3.0-2}"
arch="$(uname -m)"
case "${arch}" in
    arm64) sha256=84364eee32ba843d883fb8124867e2bf61a0cd73b6416d9897ceff7b85a24604 ;;
    x86_64) sha256=981367dd0ad4335613e91bbee453d60b6669f5d7e976d18c7bdb7f1966f26ae4 ;;
    *) echo "unsupported arch ${arch}"; exit 1 ;;
esac

name="gfortran-darwin-${arch}-native"
prefix="/opt/${name}"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

curl -fsSL -o "${work}/${name}.tar.gz" \
    "https://github.com/isuruf/gcc/releases/download/${GFORTRAN_RELEASE}/${name}.tar.gz"
echo "${sha256}  ${work}/${name}.tar.gz" | shasum -a 256 -c -

sudo mkdir -p /opt
sudo tar -xzf "${work}/${name}.tar.gz" -C /opt

# The runtime carries @rpath install names, but nothing records a matching
# rpath: MUMPS reaches the link line as a static library, so the extension is
# linked by clang++, which knows nothing about where gfortran keeps its
# runtime. Absolute install names resolve without an rpath, and give delocate
# a path it can follow when it vendors the runtime into the wheel.
runtime=(libgfortran.5.dylib libquadmath.0.dylib libgcc_s.1.1.dylib)
for f in "${runtime[@]}"; do
    lib="${prefix}/lib/${f}"
    [[ -f "${lib}" ]] || continue
    sudo chmod u+w "${lib}"
    sudo install_name_tool -id "${lib}" "${lib}"
    for dep in "${runtime[@]}"; do
        sudo install_name_tool -change "@rpath/${dep}" "${prefix}/lib/${dep}" "${lib}"
    done
    # install_name_tool invalidates the signature, which arm64 will not load.
    sudo codesign --force --sign - "${lib}"
done

"${prefix}/bin/gfortran" --version
otool -l "${prefix}/lib/libgfortran.5.dylib" \
    | awk '/LC_VERSION_MIN_MACOSX|LC_BUILD_VERSION/{f=1} f&&/version|minos/{print "  libgfortran target: "$2; exit}'

set +x
