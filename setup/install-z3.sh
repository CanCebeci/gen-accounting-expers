#!/usr/bin/env bash
# Build Z3 at $Z3_COMMIT into deps/z3/build/z3 (mirrors the workflow's build-z3 job).
# Usage: install-z3.sh [jobs]   (default: nproc)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

JOBS="${1:-$(nproc)}"

checkout_commit "$Z3_REPO_URL" "$Z3_COMMIT" "$Z3_DIR"
if [[ ! -f "$Z3_DIR/build/Makefile" ]]; then
  (cd "$Z3_DIR" && ./configure)
fi
make -C "$Z3_DIR/build" -j"$JOBS"

"$Z3_BIN" -version
