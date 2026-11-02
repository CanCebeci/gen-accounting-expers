#!/usr/bin/env bash
# Fetch the Mariposa unstable-core benchmark (58 .smt2 queries, ~280MB) from
# secure-foundations/mariposa-data using a shallow, blobless, sparse clone.
#
# This is the default benchmark of the Z3Prover/bench "Mariposa Instability
# Summary" workflow (e.g. https://github.com/Z3Prover/bench/actions/runs/26978634523).
# That workflow's copy omits two of the 60 queries in mariposa-data's
# benchmarks/unstable_core (listed in EXCLUDE below); the other 58 are
# byte-identical. Pass --all to keep them.
#
# Usage: fetch-mariposa-unsat-core.sh [--force] [--all]

set -euo pipefail

MARIPOSA_DATA_REPO_URL="${MARIPOSA_DATA_REPO_URL:-https://github.com/secure-foundations/mariposa-data.git}"
MARIPOSA_DATA_COMMIT="${MARIPOSA_DATA_COMMIT:-06d0c0a768cca55036cb53aa81e0c94a52aee2a3}"
SRC_DIR="benchmarks/unstable_core"
EXCLUDE=(s_komodo-1504.4.smt2 s_komodo-1509.4.smt2)

FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --all) EXCLUDE=() ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$(dirname "$SCRIPT_DIR")/mariposa-unsat-core"

if [[ -d "$DEST" && "$FORCE" != true ]]; then
  echo "$DEST already exists; pass --force to re-fetch." >&2
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" remote add origin "$MARIPOSA_DATA_REPO_URL"
git -C "$TMP" sparse-checkout set --no-cone "/$SRC_DIR/"
git -C "$TMP" fetch -q --depth 1 --filter=blob:none origin "$MARIPOSA_DATA_COMMIT"
git -C "$TMP" checkout -q FETCH_HEAD

for f in "${EXCLUDE[@]}"; do
  rm "$TMP/$SRC_DIR/$f"
done

rm -rf "$DEST"
mkdir -p "$DEST"
cp "$TMP/$SRC_DIR"/*.smt2 "$DEST/"
{
  echo "$MARIPOSA_DATA_REPO_URL $MARIPOSA_DATA_COMMIT $SRC_DIR"
  if [[ ${#EXCLUDE[@]} -gt 0 ]]; then echo "excluded: ${EXCLUDE[*]}"; fi
} > "$DEST/SOURCE"

echo "Fetched $(ls "$DEST"/*.smt2 | wc -l) queries into $DEST"
