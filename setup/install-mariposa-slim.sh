#!/usr/bin/env bash
# Install mariposa-slim at $MARIPOSA_COMMIT into deps/mariposa-slim: point its
# z3_local solver at our Z3 build, build smt2action, and create the Python venv.

set -euo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/common.sh"

checkout_commit "$MARIPOSA_REPO_URL" "$MARIPOSA_COMMIT" "$MARIPOSA_SLIM_DIR"

python3 - "$MARIPOSA_SLIM_DIR/config/solvers.json" "$Z3_BIN" <<'PY'
import json, sys
path, z3 = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
d.setdefault("z3_local", {})["path"] = z3
with open(path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=4)
    f.write("\n")
print(f"Set z3_local.path to {z3}")
PY

# "default" runs num_procs=60 workers, which oversubscribes machines with fewer
# CPUs (the bench wrappers drop --n-workers). Add a copy capped at 48 workers.
python3 - "$MARIPOSA_SLIM_DIR/config/expers.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
d["default_48procs"] = {**d["default"], "num_procs": 48}
with open(path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=4)
    f.write("\n")
print("Added experiment config default_48procs")
PY

(cd "$MARIPOSA_SLIM_DIR/src/smt2action" && cargo build --release)

python3 -m venv "$MARIPOSA_VENV"
"$MARIPOSA_PYTHON" -m pip install -q --upgrade pip
"$MARIPOSA_PYTHON" -m pip install -q -r "$SETUP_DIR/requirements.txt"
echo "Python env ready: $MARIPOSA_PYTHON"
