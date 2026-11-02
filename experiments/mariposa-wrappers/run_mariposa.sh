#!/bin/bash
# Adapted from scripts/mariposa-wrappers/run_mariposa.sh in Z3Prover/bench at
# f44467386541901279be4f969b3577c7cdb6fa79. Change: mariposa-slim is found via
# $MARIPOSA_SLIM_DIR (set by setup/env.sh) instead of ~/mariposa-slim.
WRAPPERS_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_BIN="${MARIPOSA_PYTHON:-python3}"
MARIPOSA_SLIM_DIR="${MARIPOSA_SLIM_DIR:-$HOME/mariposa-slim}"

SMT_INPUT=$1
EXP=${2:-"default"}
SOLVER=${3:-"z3_4_13_0"}

SMT_INPUT_ABS=$(pwd)/$SMT_INPUT

pushd "$MARIPOSA_SLIM_DIR"
    # /dev/tty is unavailable on some CI runners; stream to stderr there instead.
    if [[ -t 1 ]]; then
        WIZ_OUT=$($PYTHON_BIN src/exper_wizard.py single -i $SMT_INPUT_ABS -e $EXP -s $SOLVER --clear-existing | tee /dev/tty)
    else
        WIZ_OUT=$($PYTHON_BIN src/exper_wizard.py single -i $SMT_INPUT_ABS -e $EXP -s $SOLVER --clear-existing | tee /dev/stderr)
    fi
    PROJ=$(printf "%s\n" "$WIZ_OUT" | grep "project dir" | awk '{print $NF}' | tail -1)
    echo "PROJ: $PROJ"

    if [ -z "$PROJ" ]; then
        echo "Failed to create project directory; exper_wizard.py did not return a project dir." >&2
        popd
        exit 1
    fi

    $WRAPPERS_DIR/get_csv.sh $PROJ $EXP $SOLVER true > mariposa_res.csv
popd

mv "$MARIPOSA_SLIM_DIR"/mariposa_res.csv .
