#!/usr/bin/env bash
# Run the mariposa instability experiment on a benchmark directory and print
# per-query results, mirroring the "Run instability summary" job of the
# Z3Prover/bench "Mariposa Instability Summary" workflow.
#
# Usage: mariposa-instability.sh [bench_dir] [exp] [z3_version]
#   bench_dir   default: benchmarks/mariposa-unsat-core
#   exp         mariposa experiment config (default: default)
#   z3_version  a name from config/solver_versions, or a full commit SHA, branch
#               or tag of Z3 (default: baseline). Built first if not yet built.
#
# Outputs go to results/mariposa-instability/<bench>-<z3_version>-<timestamp>/:
#   instability-bench-output.txt  console output incl. the per-query table
#   mariposa_summary.csv          per-query unsat/unknown/timeout counts
#   mariposa_res.csv              per-mutant results of the last query
#   mariposa-logs/                mariposa log per query
#   META.txt                      versions and parameters of this run

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/setup/env.sh"

BENCH_DIR="$(realpath "${1:-$REPO_ROOT/benchmarks/mariposa-unsat-core}")"
EXP="${2:-default}"
Z3_VERSION="${3:-baseline}"

Z3_COMMIT="$(resolve_z3_version "$Z3_VERSION")"
if [[ ! -x "$(z3_bin "$Z3_COMMIT")" ]]; then
  "$REPO_ROOT/setup/install-z3.sh" "$Z3_VERSION"
fi
SOLVER="$(register_z3_solver "$Z3_COMMIT")"

OUT_DIR="$REPO_ROOT/results/mariposa-instability/$(basename "$BENCH_DIR")-${Z3_VERSION//\//-}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR/mariposa-logs"

cat > "$OUT_DIR/META.txt" <<EOF
Mariposa instability summary run
Host: $(hostname) ($(nproc) cores)
Z3: $Z3_VERSION = $(z3_version_repo "$Z3_VERSION") @ $Z3_COMMIT ($("$(z3_bin "$Z3_COMMIT")" -version))
mariposa-slim: $(git -C "$MARIPOSA_SLIM_DIR" rev-parse HEAD)
Benchmark dir: $BENCH_DIR
Experiment: $EXP
Mariposa solver key: $SOLVER
Started: $(date -Iseconds)
EOF

export MARIPOSA_LOG_EXPORT_DIR="$OUT_DIR/mariposa-logs"
status=0
"$REPO_ROOT/experiments/mariposa-wrappers/instability-bench.sh" "$BENCH_DIR" "$EXP" "$SOLVER" \
  |& tee "$OUT_DIR/instability-bench-output.txt" || status=$?
echo "Finished: $(date -Iseconds) (exit $status)" >> "$OUT_DIR/META.txt"

# instability-bench.sh writes its CSVs into the benchmark dir; move them out.
for f in mariposa_summary.csv mariposa_res.csv; do
  [[ -f "$BENCH_DIR/$f" ]] && mv "$BENCH_DIR/$f" "$OUT_DIR/"
done

echo
echo "Results in $OUT_DIR"
exit "$status"
