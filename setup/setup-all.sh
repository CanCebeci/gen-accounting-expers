#!/usr/bin/env bash
# Install all dependencies and fetch all benchmarks. Each step is safe to re-run.
# Requires: git, make, a C++ compiler, python3 (with venv), cargo.

set -euo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for cmd in git make c++ python3 cargo; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

"$SETUP_DIR/install-z3.sh"
"$SETUP_DIR/install-mariposa-slim.sh"
"$SETUP_DIR/fetch-benchmarks.sh"

echo
echo "Setup done. Run \`source setup/env.sh\` before running experiments."
