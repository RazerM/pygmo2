#!/usr/bin/env bash

# delocate will not tag a wheel for an older macOS than the libgfortran it
# bundles, and the runners' gfortran runtimes need a much newer macOS than the
# wheels' 11.0. isuruf/gcc's build targets 11.0.

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

release=gcc-11.3.0-2
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
    "https://github.com/isuruf/gcc/releases/download/${release}/${name}.tar.gz"
echo "${sha256}  ${work}/${name}.tar.gz" | shasum -a 256 -c -

sudo mkdir -p /opt
sudo tar -xzf "${work}/${name}.tar.gz" -C /opt

"${prefix}/bin/gfortran" --version
otool -l "${prefix}/lib/libgfortran.5.dylib" \
    | awk '/LC_VERSION_MIN_MACOSX|LC_BUILD_VERSION/{f=1} f&&/version|minos/{print "  libgfortran target: "$2; exit}'
