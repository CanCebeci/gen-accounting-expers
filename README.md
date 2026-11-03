This repository is for running experiments to replicate and add to the results in https://arxiv.org/pdf/2609.26345

The setup mirrors the Z3Prover/bench "Mariposa Instability Summary" workflow
(reference run: https://github.com/Z3Prover/bench/actions/runs/26978634523). By
default every dependency and benchmark is pinned to the commit that run used.

# Contents

- `benchmarks/` holds the smt2 queries. Only `benchmarks/fetch-scripts/` is
  committed; the scripts in it download the queries so they don't inflate this
  repository.
- `config/solver_versions` names the Z3 versions experiments can use (see below).
- `setup/` has scripts that install dependencies into `deps/` and fetch the benchmarks.
- `experiments/` has the scripts that run experiments and write to `results/`.
  `experiments/mariposa-wrappers/` holds adapted copies of the driver scripts
  from Z3Prover/bench (see below).

`deps/`, `results/` and the downloaded benchmarks are git-ignored.

# Quick start

```sh
setup/setup-all.sh                    # install deps + fetch benchmarks (once)
experiments/mariposa-instability.sh benchmarks/mariposa-unsat-core default baseline
```

# Prerequisites

- `git`, `make`, a C++ compiler, `python3` with `venv`, and `cargo` (Rust).
  `setup-all.sh` checks for these first and exits if one is missing.

Everything is fetched over HTTPS from public GitHub repos, so you don't need
GitHub credentials.

# Setup

`setup/setup-all.sh` runs the steps below in order. Every step is safe to re-run:
checkouts that are already at the pinned commit are skipped. You can also run any
step on its own.

| Script | What it does |
| --- | --- |
| `setup/install-z3.sh [version...]` | Builds each Z3 version into `deps/z3/<commit>/build/z3`. With no arguments it builds every version in `config/solver_versions`. Set `JOBS` to change the number of parallel make jobs (default: `nproc`). |
| `setup/install-mariposa-slim.sh` | Checks out [mariposa-slim](https://github.com/CanCebeci/mariposa-slim) into `deps/mariposa-slim`, adds the `default_50procs` experiment config (see below), builds `smt2action` with cargo, and creates a Python venv in `deps/venv` from `setup/requirements.txt`. |
| `setup/fetch-benchmarks.sh [--force]` | Runs every script in `benchmarks/fetch-scripts/`. `--force` re-downloads benchmarks that are already there. |

## Driver scripts copied from Z3Prover/bench

`experiments/mariposa-wrappers/` contains `instability-bench.sh`,
`run_mariposa.sh` and `get_csv.sh`. They are copied from the private Z3Prover/bench
repo at `f4446738` and committed here, so the setup doesn't need access to that
repo. Each file's header comment lists what was changed:

- `instability-bench.sh` and `run_mariposa.sh` use paths in this repo
  (`benchmarks/`, `$MARIPOSA_SLIM_DIR`) instead of hardcoded paths under `$HOME`.
- `get_csv.sh` always uses Python's `sqlite3` module. Upstream uses the `sqlite3`
  CLI when it is installed, but `instability-bench.sh` can't parse the CLI's
  output format, so every count came out as 0.

## Z3 versions

`config/solver_versions` gives names to Z3 versions, one per line, as
`<name> <ref> [repo]`:

```
baseline    30c74fccee4d195424588e28574ecaf0f9335f2c
mgen-fix    9d8370a13b38fa6916c681de350d99b683588f12   CanCebeci/z3
```

`baseline` is the commit the reference run used. (`mgen-fix` is only an example
of a fork commit; it isn't in the file.)

- `ref` is a full commit SHA, a branch or a tag. A branch is looked up each time
  it is used, so it follows the branch's latest commit.
- `repo` is optional: `owner/name` for a GitHub repo, or a full git URL. Use it
  for commits that only exist in a fork. It defaults to `Z3_REPO_URL`
  (`Z3Prover/z3`).

To add a version, add a line.

Anywhere a Z3 version is expected, you can give a name from this file or a full
commit SHA, branch or tag directly, e.g. `setup/install-z3.sh z3-4.13.0`. Refs
given directly are fetched from `Z3_REPO_URL`. To use a fork commit, add it to
the file with a `repo`. Every
commit gets its own checkout and build in `deps/z3/<commit>/`, so builds of
different versions don't replace each other.

## Other pinned versions and overrides

The other versions are set in `setup/common.sh`. To use a different version, set
the matching environment variable when you run the setup scripts:

| Variable | Default |
| --- | --- |
| `MARIPOSA_REPO_URL`, `MARIPOSA_COMMIT` | `CanCebeci/mariposa-slim` @ `79ec55b7` |
| `Z3_REPO_URL` | `https://github.com/Z3Prover/z3.git` |
| `DEPS_DIR` | `deps/` |

The benchmark fetch script has its own overrides: `MARIPOSA_DATA_REPO_URL`
and `MARIPOSA_DATA_COMMIT` (default `secure-foundations/mariposa-data` @ `06d0c0a7`).

The Python packages in `setup/requirements.txt` are unpinned, as in the upstream
workflow. That file lists the versions the reference run had.

# Benchmarks

| Benchmark | Fetch script | Contents |
| --- | --- | --- |
| `benchmarks/mariposa-unsat-core/` | `fetch-mariposa-unsat-core.sh [--force] [--all]` | 58 `.smt2` queries (~280 MB) from `benchmarks/unstable_core` in [secure-foundations/mariposa-data](https://github.com/secure-foundations/mariposa-data), downloaded with a shallow sparse clone. |

`mariposa-unsat-core` matches the default benchmark of the reference workflow.
mariposa-data's `unstable_core` has 60 queries, but the workflow's copy leaves out
`s_komodo-1504.4.smt2` and `s_komodo-1509.4.smt2`, so the fetch script excludes
them too. The other 58 are byte-identical to the workflow's copies. Pass `--all`
to include the two extra queries.

Each fetched benchmark directory has a `SOURCE` file that records the repo, commit
and path it was fetched from. To add a benchmark, put a new `*.sh` script in
`benchmarks/fetch-scripts/`. `setup/fetch-benchmarks.sh` will pick it up.

# Running experiments

## Mariposa instability

```sh
experiments/mariposa-instability.sh [bench_dir] [exp] [z3_version]
```

| Argument | Default | Meaning |
| --- | --- | --- |
| `bench_dir` | `benchmarks/mariposa-unsat-core` | Directory of `.smt2` queries to run |
| `exp` | `default` | Experiment config in `deps/mariposa-slim/config/expers.json` |
| `z3_version` | `baseline` | Z3 version to test: a name from `config/solver_versions`, or a full commit SHA, branch or tag (see [Z3 versions](#z3-versions)) |

For each query, mariposa generates mutants by shuffling, renaming and reseeding
the query, and runs Z3 on each one. The script reports how many mutants came out
unsat, unknown or timeout. It sources `setup/env.sh` itself, so you don't need to
source anything first.

If the requested Z3 version hasn't been built yet, the script runs
`setup/install-z3.sh` for it first, which can take a while. It then registers the
build in `deps/mariposa-slim/config/solvers.json` as `z3_<first 12 chars of the
commit>` and drops any entries whose binary no longer exists, since mariposa
won't load if one is missing.

The `default` config makes 33 mutants per query with a 60 s timeout and runs 60
workers in parallel. The upstream wrappers ignore `--n-workers`, so on a machine
with fewer than 60 cores this overloads the CPUs and can cause spurious timeouts.
Use `default_50procs` instead, which is the same config with 50 workers:

```sh
experiments/mariposa-instability.sh benchmarks/mariposa-unsat-core default_50procs baseline
```

Each run writes to `results/mariposa-instability/<bench>-<z3_version>-<YYYYmmdd-HHMMSS>/`
(any `/` in the version name becomes `-`):

| File | Contents |
| --- | --- |
| `instability-bench-output.txt` | Console output, including the per-query table and the summary totals |
| `mariposa_summary.csv` | One row per query: `unsat_count`, `unknown_count`, `timeout_count`, `status`, `elapsed_sec` |
| `mariposa_res.csv` | Per-mutant results for the last query only |
| `mariposa-logs/` | One mariposa log per query (`mariposa_run_<i>.log`) |
| `META.txt` | Host, core count, Z3 version name, repo and commit, mariposa-slim commit, mariposa solver key, arguments, start/end times and exit status |

## Running tools by hand

To call Z3, mariposa or the bench wrappers yourself, first run
`source setup/env.sh`. This exports `MARIPOSA_SLIM_DIR`, `MARIPOSA_PYTHON` and
`MARIPOSA_WRAPPER`. It also defines shell functions: `z3_bin "$(resolve_z3_version baseline)"`
prints the path of the baseline Z3 binary.
