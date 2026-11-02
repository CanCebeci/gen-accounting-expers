#!/usr/bin/env bash
# Run every benchmark fetch script. Extra args (e.g. --force) are passed through.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

for script in "$REPO_ROOT"/benchmarks/fetch-scripts/*.sh; do
  echo "== $(basename "$script")"
  "$script" "$@"
done
