#!/usr/bin/env bash
# Run the mariposa instability experiment on a benchmark directory and print
# per-query results, mirroring the "Run instability summary" job of the
# Z3Prover/bench "Mariposa Instability Summary" workflow.
#
# Usage: mariposa-instability.sh [bench_dir] [exp] [solver]
#   bench_dir  default: benchmarks/mariposa-unsat-core
#   exp        mariposa experiment config (default: default)
#   solver     mariposa solver key (default: z3_local, i.e. deps/z3/build/z3)
#
# Outputs go to results/mariposa-instability/<bench>-<timestamp>/:
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
SOLVER="${3:-z3_local}"

OUT_DIR="$REPO_ROOT/results/mariposa-instability/$(basename "$BENCH_DIR")-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR/mariposa-logs"

cat > "$OUT_DIR/META.txt" <<EOF
Mariposa instability summary run
Host: $(hostname) ($(nproc) cores)
Z3: $Z3_COMMIT ($("$Z3_BIN" -version))
mariposa-slim: $(git -C "$MARIPOSA_SLIM_DIR" rev-parse HEAD)
Benchmark dir: $BENCH_DIR
Experiment: $EXP
Solver key: $SOLVER
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
