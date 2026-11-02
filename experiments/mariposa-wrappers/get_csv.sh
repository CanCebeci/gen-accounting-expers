#!/bin/bash
# Adapted from scripts/mariposa-wrappers/get_csv.sh in Z3Prover/bench at
# f44467386541901279be4f969b3577c7cdb6fa79. Change: always uses Python's sqlite3
# module. Upstream prefers the sqlite3 CLI when installed, but that writes empty
# fields as "" while instability-bench.sh counts results by grepping ',,,<code>',
# so every count came out 0.

PROJ=$1
EXP=$2
SOLVER=$3

SINGLE=${4:-true}

if [ "$SINGLE" != "true" ]; then
    DB_PATH="data/dbs/${PROJ:11}/$EXP.db"
    TABLE_NAME="${PROJ:11:-8}_base_z3_${SOLVER}_exp"
else
    DB_PATH="$PROJ/$EXP.db"
    TABLE_NAME="${PROJ:10}_base_z3_${SOLVER}_exp"
fi

QUERY="SELECT query_path, vanilla_path, perturbation,command,std_out,std_error,result_code,elapsed_milli,check_sat_id,timestamp FROM ${TABLE_NAME}"

python3 - "$DB_PATH" "$QUERY" <<'PY'
import csv
import sqlite3
import sys

db_path = sys.argv[1]
query = sys.argv[2]

conn = sqlite3.connect(db_path)
try:
    cur = conn.cursor()
    cur.execute(query)
    writer = csv.writer(sys.stdout)
    writer.writerow([d[0] for d in cur.description])
    writer.writerows(cur.fetchall())
finally:
    conn.close()
PY
