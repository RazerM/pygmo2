#!/usr/bin/env bash

# Prepare a manylinux2014 (CentOS 7) container for the vcpkg build.
#
# CentOS 7 is EOL: the repositories the image is configured with now return
# 403, so zip is fetched straight from the versioned vault path instead of
# through yum. vcpkg needs it only to populate its binary cache, but without
# that cache every interpreter would rebuild the whole C++ stack.

set -Eeuo pipefail
set -x

VAULT="${VAULT:-https://vault.centos.org/7.9.2009/os/x86_64/Packages/}"

if ! command -v zip > /dev/null; then
    rpm_name="$(curl -fsSL --max-time 60 "${VAULT}" \
        | grep -oE '"zip-[0-9][^"]*\.rpm"' | tr -d '"' | head -1)"
    if [[ -z "${rpm_name}" ]]; then
        echo "Could not find a zip rpm under ${VAULT}"
        exit 1
    fi
    curl -fsSL --max-time 120 -o /tmp/zip.rpm "${VAULT}${rpm_name}"
    rpm -i /tmp/zip.rpm
fi

# vcpkg ships a prebuilt ninja that needs a newer libstdc++ than CentOS 7 has,
# so VCPKG_FORCE_SYSTEM_BINARIES is set for these builds and a usable ninja has
# to be on PATH.
"${PYBIN:-/opt/python/cp311-cp311/bin}/pip" install --quiet ninja
ln -sf "${PYBIN:-/opt/python/cp311-cp311/bin}/ninja" /usr/local/bin/ninja
ninja --version

set +x
