#!/usr/bin/env bash
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for dependency in qs dbus-run-session busctl python3 Xvfb; do
    command -v "$dependency" >/dev/null || {
        printf 'Missing test dependency: %s (see README.md)\n' "$dependency" >&2
        exit 1
    }
done
# A fresh bus owns the test daemon and clients. The desktop bus is never used.
exec dbus-run-session -- env EMILIA_TEST_SESSION=1 python3 "$test_dir/integration.py"
