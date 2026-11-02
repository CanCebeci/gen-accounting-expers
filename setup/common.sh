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

MARIPOSA_WRAPPER="$REPO_ROOT/experiments/mariposa-wrappers/run_mariposa.sh"

# checkout_commit <url> <commit> <dir>
# Shallow-fetch a single commit into <dir>, reusing an existing checkout.
checkout_commit() {
  local url="$1" commit="$2" dir="$3"
  if [[ ! -d "$dir/.git" ]]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  if [[ "$(git -C "$dir" rev-parse -q --verify HEAD 2>/dev/null)" == "$commit" ]]; then
    echo "$dir already at $commit"
    return
  fi
  git -C "$dir" fetch -q --depth 1 origin "$commit"
  git -C "$dir" checkout -q --force FETCH_HEAD
  echo "Checked out $url@$commit into $dir"
}
