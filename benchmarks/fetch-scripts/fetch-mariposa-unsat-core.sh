#!/usr/bin/env bash
# Fetch the mariposa unsat-core benchmark (58 .smt2 queries, ~280MB) used by the
# "Mariposa Instability Summary" workflow in Z3Prover/bench
# (e.g. https://github.com/Z3Prover/bench/actions/runs/26978634523), whose
# default benchmark_dir is inputs/mariposa/unstable_core.
#
# Z3Prover/bench is private, so you need GitHub access to it (SSH key by default;
# set BENCH_REPO_URL=https://github.com/Z3Prover/bench.git to use HTTPS/gh auth).
#
# Usage: fetch-mariposa-unsat-core.sh [--force]

set -euo pipefail

BENCH_REPO_URL="${BENCH_REPO_URL:-git@github.com:Z3Prover/bench.git}"
# Commit of Z3Prover/bench used by the run above; override to fetch another version.
BENCH_COMMIT="${BENCH_COMMIT:-f44467386541901279be4f969b3577c7cdb6fa79}"
SRC_DIR="inputs/mariposa/unstable_core"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$(dirname "$SCRIPT_DIR")/mariposa-unsat-core"

if [[ -d "$DEST" && "${1:-}" != "--force" ]]; then
  echo "$DEST already exists; pass --force to re-fetch." >&2
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Blobless + sparse checkout so only the benchmark directory is downloaded.
git -C "$TMP" init -q
git -C "$TMP" remote add origin "$BENCH_REPO_URL"
git -C "$TMP" sparse-checkout set --no-cone "/$SRC_DIR/"
git -C "$TMP" fetch -q --depth 1 --filter=blob:none origin "$BENCH_COMMIT"
git -C "$TMP" checkout -q FETCH_HEAD

rm -rf "$DEST"
mkdir -p "$DEST"
cp "$TMP/$SRC_DIR"/*.smt2 "$DEST/"
echo "$BENCH_REPO_URL $BENCH_COMMIT $SRC_DIR" > "$DEST/SOURCE"

echo "Fetched $(ls "$DEST"/*.smt2 | wc -l) queries into $DEST"
