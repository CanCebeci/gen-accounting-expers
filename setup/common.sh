# Shared paths and pinned versions for the setup scripts. Source, don't run.
#
# Versions default to those used by the Z3Prover/bench "Mariposa Instability
# Summary" run https://github.com/Z3Prover/bench/actions/runs/26978634523.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${DEPS_DIR:-$REPO_ROOT/deps}"

Z3_REPO_URL="${Z3_REPO_URL:-https://github.com/Z3Prover/z3.git}"
Z3_COMMIT="${Z3_COMMIT:-30c74fccee4d195424588e28574ecaf0f9335f2c}"
Z3_DIR="$DEPS_DIR/z3"
Z3_BIN="$Z3_DIR/build/z3"

MARIPOSA_REPO_URL="${MARIPOSA_REPO_URL:-https://github.com/CanCebeci/mariposa-slim.git}"
MARIPOSA_COMMIT="${MARIPOSA_COMMIT:-79ec55b7caa27fb796b861784552a43c54ec2743}"
MARIPOSA_SLIM_DIR="$DEPS_DIR/mariposa-slim"
MARIPOSA_VENV="$DEPS_DIR/venv"
MARIPOSA_PYTHON="$MARIPOSA_VENV/bin/python"

# Z3Prover/bench is private; set to the HTTPS URL to use gh auth instead of SSH.
BENCH_REPO_URL="${BENCH_REPO_URL:-git@github.com:Z3Prover/bench.git}"
BENCH_COMMIT="${BENCH_COMMIT:-f44467386541901279be4f969b3577c7cdb6fa79}"
BENCH_SCRIPTS_DIR="$DEPS_DIR/bench-scripts"
MARIPOSA_WRAPPER="$BENCH_SCRIPTS_DIR/mariposa-wrappers/run_mariposa.sh"

# checkout_commit <url> <commit> <dir> [sparse paths...]
# Shallow-fetch a single commit into <dir>, reusing an existing checkout.
checkout_commit() {
  local url="$1" commit="$2" dir="$3"
  shift 3
  if [[ ! -d "$dir/.git" ]]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  if [[ "$(git -C "$dir" rev-parse -q --verify HEAD 2>/dev/null)" == "$commit" ]]; then
    echo "$dir already at $commit"
    return
  fi
  if [[ $# -gt 0 ]]; then
    git -C "$dir" sparse-checkout set --no-cone "$@"
    git -C "$dir" fetch -q --depth 1 --filter=blob:none origin "$commit"
  else
    git -C "$dir" fetch -q --depth 1 origin "$commit"
  fi
  git -C "$dir" checkout -q --force FETCH_HEAD
  echo "Checked out $url@$commit into $dir"
}
