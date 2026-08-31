#!/usr/bin/env bash

# Install what the vcpkg dependencies need on a macOS runner.
#
# coin-or-ipopt and mumps build with autotools, and autoconf-archive in
# particular is not on the images. MUMPS is Fortran, so a gfortran is needed
# too, and the images carry no unversioned one on PATH.
#
# The Fortran runtime is the awkward part. delocate bundles the libgfortran
# that the extension resolves against and then refuses to tag the wheel as
# supporting macOS older than that runtime does. Every gfortran on the images
# ships a runtime with a 14.0 minimum, which would drag every macOS wheel up
# from 11.0. scipy hits the same problem and solves it by shipping a runtime
# built against an older SDK in its scipy-openblas wheels, whose README
# explicitly invites other projects to use them that way, so take the
# libgfortran/libquadmath/libgcc_s from there and let gfortran link those.

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

prefix="$(brew --prefix)"
if ! command -v gfortran > /dev/null; then
    newest="$(ls "${prefix}"/bin/gfortran-* 2> /dev/null | sort -V | tail -1 || true)"
    [[ -n "${newest}" ]] && ln -sf "${newest}" "${prefix}/bin/gfortran" || brew install gcc
fi

runtime_dir="$(gfortran -print-file-name=libgfortran.dylib)"
runtime_dir="$(dirname "${runtime_dir}")"
echo "gfortran runtime dir: ${runtime_dir}"
for lib in libgfortran.5.dylib libquadmath.0.dylib libgcc_s.1.1.dylib; do
    [[ -f "${runtime_dir}/${lib}" ]] &&
        echo "  before: ${lib} minos $(otool -l "${runtime_dir}/${lib}" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
done

# Fetch the low-deployment-target runtime from scipy-openblas32.
work="$(mktemp -d)"
url="$(python3 - <<'PY'
import json, urllib.request
d = json.load(urllib.request.urlopen("https://pypi.org/pypi/scipy-openblas32/json", timeout=60))
for u in d["urls"]:
    if "macosx" in u["filename"] and "arm64" in u["filename"]:
        print(u["url"]); break
PY
)"
echo "scipy-openblas32 wheel: ${url}"
curl -fsSL -o "${work}/sob.whl" "${url}"
( cd "${work}" && unzip -q sob.whl )

for lib in libgfortran.5.dylib libquadmath.0.dylib libgcc_s.1.1.dylib; do
    src="$(find "${work}" -name "${lib}" | head -1)"
    if [[ -n "${src}" && -f "${runtime_dir}/${lib}" ]]; then
        echo "  replacing ${lib} (minos $(otool -l "${src}" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}'))"
        cp -f "${src}" "${runtime_dir}/${lib}"
    fi
done
rm -rf "${work}"

for lib in libgfortran.5.dylib libquadmath.0.dylib libgcc_s.1.1.dylib; do
    [[ -f "${runtime_dir}/${lib}" ]] &&
        echo "  after: ${lib} minos $(otool -l "${runtime_dir}/${lib}" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')"
done

set +x
