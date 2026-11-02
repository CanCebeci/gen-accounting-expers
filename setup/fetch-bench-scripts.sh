#!/usr/bin/env bash
# Fetch the experiment driver scripts from Z3Prover/bench at $BENCH_COMMIT into
# deps/bench-scripts. run_mariposa.sh hardcodes ~/mariposa-slim; the copy is
# patched to use $MARIPOSA_SLIM_DIR (from setup/env.sh) instead.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

checkout_commit "$BENCH_REPO_URL" "$BENCH_COMMIT" "$DEPS_DIR/bench" \
  /scripts/instability-bench.sh /scripts/mariposa-wrappers/

rm -rf "$BENCH_SCRIPTS_DIR"
mkdir -p "$BENCH_SCRIPTS_DIR"
cp -r "$DEPS_DIR/bench/scripts/instability-bench.sh" \
      "$DEPS_DIR/bench/scripts/mariposa-wrappers" "$BENCH_SCRIPTS_DIR/"
sed -i 's#~/mariposa-slim#"${MARIPOSA_SLIM_DIR:-$HOME/mariposa-slim}"#g' \
  "$BENCH_SCRIPTS_DIR/mariposa-wrappers/run_mariposa.sh"
# get_csv.sh prefers the sqlite3 CLI, which writes empty fields as "", but
# instability-bench.sh counts results by grepping ',,,<code>' (the output of
# its python fallback). Always use the python fallback so counts aren't all 0.
sed -i 's#^if command -v sqlite3 .*then$#if false; then  \# patched: see setup/fetch-bench-scripts.sh#' \
  "$BENCH_SCRIPTS_DIR/mariposa-wrappers/get_csv.sh"
grep -q '^if false; then' "$BENCH_SCRIPTS_DIR/mariposa-wrappers/get_csv.sh"
chmod +x "$BENCH_SCRIPTS_DIR"/*.sh "$BENCH_SCRIPTS_DIR"/mariposa-wrappers/*.sh

echo "Bench scripts in $BENCH_SCRIPTS_DIR"
