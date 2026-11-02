#!/usr/bin/env bash
# Build Z3 into deps/z3/<commit>/build/z3 (mirrors the workflow's build-z3 job).
# Usage: install-z3.sh [version...]
#   version  a name from config/solver_versions (fetched from the repo on its
#            line, if any), or a full commit SHA, branch or tag of $Z3_REPO_URL
#            (default: every name in config/solver_versions)
# Set JOBS to change the number of parallel make jobs (default: nproc).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

JOBS="${JOBS:-$(nproc)}"

if [[ $# -eq 0 ]]; then
  mapfile -t versions < <(z3_versions)
else
  versions=("$@")
fi

for version in "${versions[@]}"; do
  commit="$(resolve_z3_version "$version")"
  dir="$Z3_BUILDS_DIR/$commit"
  echo "== Z3 $version ($commit)"
  checkout_commit "$(z3_version_repo "$version")" "$commit" "$dir"
  if [[ ! -f "$dir/build/Makefile" ]]; then
    (cd "$dir" && ./configure)
  fi
  make -C "$dir/build" -j"$JOBS"
  "$(z3_bin "$commit")" -version
done
