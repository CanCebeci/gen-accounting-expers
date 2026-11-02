# Shared paths and pinned versions for the setup scripts. Source, don't run.
#
# Versions default to those used by the Z3Prover/bench "Mariposa Instability
# Summary" run https://github.com/Z3Prover/bench/actions/runs/26978634523.
# Z3 versions are named in config/solver_versions; see resolve_z3_version.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${DEPS_DIR:-$REPO_ROOT/deps}"

Z3_REPO_URL="${Z3_REPO_URL:-https://github.com/Z3Prover/z3.git}"
Z3_VERSIONS_FILE="${Z3_VERSIONS_FILE:-$REPO_ROOT/config/solver_versions}"
# Each Z3 commit gets its own checkout and build in $Z3_BUILDS_DIR/<commit>.
Z3_BUILDS_DIR="$DEPS_DIR/z3"

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
  git -C "$dir" remote set-url origin "$url"
  if [[ "$(git -C "$dir" rev-parse -q --verify HEAD 2>/dev/null)" == "$commit" ]]; then
    echo "$dir already at $commit"
    return
  fi
  git -C "$dir" fetch -q --depth 1 origin "$commit"
  git -C "$dir" checkout -q --force FETCH_HEAD
  echo "Checked out $url@$commit into $dir"
}

# z3_versions: print the names listed in config/solver_versions.
z3_versions() {
  awk '!/^[[:space:]]*(#|$)/ {print $1}' "$Z3_VERSIONS_FILE"
}

# z3_version_repo <name|ref>: print the repo URL to fetch a Z3 version from: the
# optional third field of its config/solver_versions line ("owner/repo" on GitHub
# or a full URL), else $Z3_REPO_URL.
z3_version_repo() {
  local repo
  repo="$(awk -v n="$1" '!/^[[:space:]]*#/ && $1 == n {print $3; exit}' "$Z3_VERSIONS_FILE")"
  if [[ -z "$repo" ]]; then
    echo "$Z3_REPO_URL"
  elif [[ "$repo" == *:* ]]; then
    echo "$repo"
  else
    echo "https://github.com/$repo.git"
  fi
}

# resolve_z3_version <name|ref>: print the Z3 commit for a name from
# config/solver_versions, or for a full commit SHA, branch or tag of $Z3_REPO_URL.
resolve_z3_version() {
  local ref sha full repo
  ref="$(awk -v n="$1" '!/^[[:space:]]*#/ && $1 == n {print $2; exit}' "$Z3_VERSIONS_FILE")"
  ref="${ref:-$1}"
  repo="$(z3_version_repo "$1")"
  if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
    echo "$ref"
    return
  fi
  # Prefer the commit an annotated tag points to over the tag object itself.
  for full in "refs/tags/$ref^{}" "refs/tags/$ref" "refs/heads/$ref"; do
    sha="$(git ls-remote "$repo" "$full" | awk -v r="$full" '$2 == r {print $1}')"
    if [[ -n "$sha" ]]; then
      echo "$sha"
      return
    fi
  done
  echo "Unknown Z3 version '$1': not in $Z3_VERSIONS_FILE, and not a full commit SHA," \
       "branch or tag of $repo" >&2
  return 1
}

# z3_bin <commit>: path of the Z3 binary built for <commit>.
z3_bin() {
  echo "$Z3_BUILDS_DIR/$1/build/z3"
}

# register_z3_solver <commit>: add the Z3 build for <commit> to mariposa-slim's
# config/solvers.json as z3_<short commit>, and print that solver key. Entries
# whose binary is missing are dropped, since mariposa refuses to load them.
register_z3_solver() {
  local commit="$1" key="z3_${1:0:12}" date
  date="$(git -C "$Z3_BUILDS_DIR/$commit" log -1 --format=%cd --date=format:%Y/%m/%d)"
  python3 - "$MARIPOSA_SLIM_DIR/config/solvers.json" "$key" "$(z3_bin "$commit")" "$date" <<'PY'
import json, os, sys
path, key, z3, date = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
d = {k: v for k, v in d.items() if os.path.exists(os.path.expanduser(v["path"]))}
d[key] = {"path": z3, "date": date}
with open(path, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=4)
    f.write("\n")
PY
  echo "$key"
}
