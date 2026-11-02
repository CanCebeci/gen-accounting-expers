#!/usr/bin/env bash
# Adapted from scripts/instability-bench.sh in Z3Prover/bench at
# f44467386541901279be4f969b3577c7cdb6fa79. Changes: the benchmark dir defaults
# to benchmarks/mariposa-unsat-core and the wrapper to the sibling
# run_mariposa.sh, instead of paths under $HOME / $GITHUB_WORKSPACE.

set -u
set -o pipefail

WRAPPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BENCH_DIR="${1:-$WRAPPERS_DIR/../../benchmarks/mariposa-unsat-core}"
EXP="${2:-default}"
SOLVER="${3:-z3_local}"

WRAPPER="${MARIPOSA_WRAPPER:-$WRAPPERS_DIR/run_mariposa.sh}"

if [[ ! -d "$BENCH_DIR" ]]; then
    echo "Error: UNSAT directory not found: $BENCH_DIR" >&2
    exit 1
fi

if [[ -z "$WRAPPER" || ! -x "$WRAPPER" ]]; then
    echo "Error: run_mariposa.sh not found or not executable." >&2
    echo "Set MARIPOSA_WRAPPER to the script path." >&2
    exit 1
fi

mapfile -t QUERIES < <(find "$BENCH_DIR" -maxdepth 1 -type f -name '*.smt2' | sort)

if [[ ${#QUERIES[@]} -eq 0 ]]; then
    echo "No .smt2 queries found in: $BENCH_DIR"
    exit 0
fi

RESULTS_CSV="$BENCH_DIR/mariposa_summary.csv"
{
    echo "query,unsat_count,unknown_count,timeout_count,status,elapsed_sec"
} > "$RESULTS_CSV"

# If an artifact export directory is provided, write logs directly there (avoids
# tmpfs / in-RAM storage). Otherwise fall back to a regular temp directory on disk.
LOG_EXPORT_DIR="${MARIPOSA_LOG_EXPORT_DIR:-}"
if [[ -n "$LOG_EXPORT_DIR" ]]; then
    RUN_LOG_DIR="$LOG_EXPORT_DIR"
    mkdir -p "$RUN_LOG_DIR"
    # Logs land directly in the artifact dir; nothing to copy on exit.
    cleanup_logs() { :; }
else
    RUN_LOG_DIR=$(mktemp -d -t mariposa_logs.XXXXXX)
    cleanup_logs() { rm -rf "$RUN_LOG_DIR"; }
fi
trap cleanup_logs EXIT

echo "Running ${#QUERIES[@]} queries from: $BENCH_DIR"
echo "Wrapper: $WRAPPER"
echo "Experiment: $EXP"
echo "Solver: $SOLVER"
echo

idx=0
for qpath in "${QUERIES[@]}"; do
    idx=$((idx + 1))
    query="$(basename "$qpath")"
    printf '[%d/%d] %s\n' "$idx" "${#QUERIES[@]}" "$query"

    start_ts=$(date +%s)
    run_status="ok"
    log_file="$RUN_LOG_DIR/mariposa_run_${idx}.log"

    (
        cd "$BENCH_DIR" || exit 1
        CORES=$(nproc)
        MARIPOSA_VERBOSE=1 "$WRAPPER" "$query" "$EXP" "$SOLVER" --n-workers "$CORES"
    ) >"$log_file" 2>&1 &
    mariposa_pid=$!

    # Print latest mariposa progress every 5 seconds.
    (
        last=""
        while kill -0 "$mariposa_pid" 2>/dev/null; do
            if [[ -f "$log_file" ]]; then
                new=$(grep -aEo '\[DEBUG\] finished: [0-9]+/[0-9]+' "$log_file" | tail -1)
                if [[ -z "$new" ]]; then
                    new=$(tail -20 "$log_file" | grep -av '^$' | tail -1)
                fi
                if [[ "$new" != "$last" && -n "$new" ]]; then
                    echo "    $new"
                    last="$new"
                fi
            fi
            sleep 5
        done
    ) &
    progress_pid=$!

    wait "$mariposa_pid"
    exit_code=$?
    kill "$progress_pid" 2>/dev/null || true

    end_ts=$(date +%s)
    elapsed=$((end_ts - start_ts))

    if [[ $exit_code -ne 0 ]]; then
        run_status="failed"
        unsat="-1"
        unknown="-1"
        timeout="-1"
        echo "  status: failed"
    else
        if [[ -f "$BENCH_DIR/mariposa_res.csv" ]]; then
            unsat=$(grep -ac ',,,2' "$BENCH_DIR/mariposa_res.csv" || true)
            unknown=$(grep -ac ',,,4' "$BENCH_DIR/mariposa_res.csv" || true)
            timeout=$(grep -ac ',,,3' "$BENCH_DIR/mariposa_res.csv" || true)
            echo "  unsat=$unsat unknown=$unknown timeout=$timeout (${elapsed}s)"
        else
            run_status="failed"
            unsat="-1"
            unknown="-1"
            timeout="-1"
            echo "  status: failed (missing $BENCH_DIR/mariposa_res.csv)"
        fi
    fi

    echo "$query,$unsat,$unknown,$timeout,$run_status,$elapsed" >> "$RESULTS_CSV"
done

echo
echo "Per-query results:"
if command -v column >/dev/null 2>&1; then
    column -s, -t "$RESULTS_CSV"
else
    cat "$RESULTS_CSV"
fi

echo
ok_queries=$(awk -F, 'NR>1 && $5=="ok" {c++} END {print c+0}' "$RESULTS_CSV")
failed_queries=$(awk -F, 'NR>1 && $5=="failed" {c++} END {print c+0}' "$RESULTS_CSV")
total_unsat=$(awk -F, 'NR>1 && $5=="ok" {s+=$2} END {print s+0}' "$RESULTS_CSV")
total_unknown=$(awk -F, 'NR>1 && $5=="ok" {s+=$3} END {print s+0}' "$RESULTS_CSV")
total_timeout=$(awk -F, 'NR>1 && $5=="ok" {s+=$4} END {print s+0}' "$RESULTS_CSV")
queries_with_unsat=$(awk -F, 'NR>1 && $5=="ok" && $2>0 {c++} END {print c+0}' "$RESULTS_CSV")
queries_with_unknown=$(awk -F, 'NR>1 && $5=="ok" && $3>0 {c++} END {print c+0}' "$RESULTS_CSV")
queries_with_timeout=$(awk -F, 'NR>1 && $5=="ok" && $4>0 {c++} END {print c+0}' "$RESULTS_CSV")

echo "Summary:"
echo "  total_queries=${#QUERIES[@]}"
echo "  ok_queries=$ok_queries"
echo "  failed_queries=$failed_queries"
echo "  total_unsat_mutants=$total_unsat"
echo "  total_unknown_mutants=$total_unknown"
echo "  total_timeout_mutants=$total_timeout"
echo "  queries_with_unsat=$queries_with_unsat"
echo "  queries_with_unknown=$queries_with_unknown"
echo "  queries_with_timeout=$queries_with_timeout"
echo "  results_csv=$RESULTS_CSV"
