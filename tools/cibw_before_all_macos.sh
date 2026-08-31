#!/usr/bin/env bash

# Install what the vcpkg dependencies need on a macOS runner.
#
# coin-or-ipopt and mumps build with autotools, and autoconf-archive in
# particular is not on the images. MUMPS is Fortran, and the images carry no
# unversioned gfortran on PATH, so one has to be selected.

set -Eeuo pipefail
set -x

brew install autoconf autoconf-archive automake libtool

prefix="$(brew --prefix)"

# delocate bundles the Fortran runtime of whichever gfortran built MUMPS, and
# refuses to produce a wheel whose tag claims support older than that runtime.
# The newest gfortran therefore drags the wheel's floor up to whatever macOS
# its bottle targeted, so pick the candidate with the lowest minimum instead.
minos_of() {
    local fc="$1" lib
    lib="$("${fc}" -print-file-name=libgfortran.dylib 2> /dev/null || true)"
    [[ -f "${lib}" ]] || lib="$("${fc}" -print-file-name=libgfortran.5.dylib 2> /dev/null || true)"
    [[ -f "${lib}" ]] || return 1
    otool -l "${lib}" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}'
}

best=""
best_minos=""
for fc in "${prefix}"/bin/gfortran-*; do
    [[ -x "${fc}" ]] || continue
    m="$(minos_of "${fc}" || true)"
    echo "candidate ${fc} -> libgfortran minos ${m:-unknown}"
    [[ -n "${m}" ]] || continue
    if [[ -z "${best_minos}" ]] || [[ "$(printf '%s\n%s\n' "${m}" "${best_minos}" | sort -V | head -1)" == "${m}" ]]; then
        best="${fc}"
        best_minos="${m}"
    fi
done

if [[ -z "${best}" ]]; then
    if command -v gfortran > /dev/null; then
        best="$(command -v gfortran)"
    else
        brew install gcc
        best="${prefix}/bin/gfortran"
    fi
fi

echo "selected ${best} (libgfortran minos ${best_minos:-unknown})"
ln -sf "${best}" "${prefix}/bin/gfortran"
gfortran --version

set +x
