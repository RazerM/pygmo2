#!/usr/bin/env bash

# Run the pygmo test suite against a freshly built wheel.

set -Eeuo pipefail
set -x

# Keep at least 2 engines: the ipyparallel island tests target engine id 1.
ipcluster start --daemonize=True -n 2
sleep 20  # let the engines come up

python -c "import pygmo; pygmo.test.run_test_suite(1); pygmo.mp_island.shutdown_pool(); pygmo.mp_bfe.shutdown_pool()"

ipcluster stop || true

set +x
