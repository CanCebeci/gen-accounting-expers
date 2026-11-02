This repository is for running experiments to replicate and add to the results in https://arxiv.org/pdf/2609.26345

The setup mirrors the Z3Prover/bench "Mariposa Instability Summary" workflow
(reference run: https://github.com/Z3Prover/bench/actions/runs/26978634523). By
default every dependency and benchmark is pinned to the commit that run used.

# Contents

- `benchmarks/` holds the smt2 queries. Only `benchmarks/fetch-scripts/` is
  committed; the scripts in it download the queries so they don't inflate this
  repository.
- `setup/` has scripts that install dependencies into `deps/` and fetch the benchmarks.
- `experiments/` has the scripts that run experiments and write to `results/`.
  `experiments/mariposa-wrappers/` holds adapted copies of the driver scripts
  from Z3Prover/bench (see below).

`deps/`, `results/` and the downloaded benchmarks are git-ignored.

# Quick start

```sh
setup/setup-all.sh                    # install deps + fetch benchmarks (once)
experiments/mariposa-instability.sh   # run the instability experiment
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
| `setup/install-z3.sh [jobs]` | Builds Z3 into `deps/z3/build/z3`. `jobs` defaults to `nproc`. |
| `setup/install-mariposa-slim.sh` | Checks out [mariposa-slim](https://github.com/CanCebeci/mariposa-slim) into `deps/mariposa-slim`, points its `z3_local` solver at the Z3 built above, adds the `default_48procs` experiment config (see below), builds `smt2action` with cargo, and creates a Python venv in `deps/venv` from `setup/requirements.txt`. |
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

## Pinned versions and overrides

The versions are set in `setup/common.sh`. To use a different version, set the
matching environment variable when you run the setup scripts:

| Variable | Default |
| --- | --- |
| `Z3_REPO_URL`, `Z3_COMMIT` | `Z3Prover/z3` @ `30c74fcc` |
| `MARIPOSA_REPO_URL`, `MARIPOSA_COMMIT` | `CanCebeci/mariposa-slim` @ `79ec55b7` |
| `DEPS_DIR` | `deps/` |

For example, `Z3_COMMIT=<sha> setup/install-z3.sh` builds another Z3 version.
`deps/z3` holds one Z3 checkout at a time, so this replaces the existing build.
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
experiments/mariposa-instability.sh [bench_dir] [exp] [solver]
```

| Argument | Default | Meaning |
| --- | --- | --- |
| `bench_dir` | `benchmarks/mariposa-unsat-core` | Directory of `.smt2` queries to run |
| `exp` | `default` | Experiment config in `deps/mariposa-slim/config/expers.json` |
| `solver` | `z3_local` | Solver key in `deps/mariposa-slim/config/solvers.json`. `z3_local` is `deps/z3/build/z3`. |

For each query, mariposa generates mutants by shuffling, renaming and reseeding
the query, and runs Z3 on each one. The script reports how many mutants came out
unsat, unknown or timeout. It sources `setup/env.sh` itself, so you don't need to
source anything first.

The `default` config makes 33 mutants per query with a 60 s timeout and runs 60
workers in parallel. The upstream wrappers ignore `--n-workers`, so on a machine
with fewer than 60 cores this overloads the CPUs and can cause spurious timeouts.
Use `default_48procs` instead, which is the same config with 48 workers:

```sh
experiments/mariposa-instability.sh benchmarks/mariposa-unsat-core default_48procs
```

Each run writes to `results/mariposa-instability/<bench>-<YYYYmmdd-HHMMSS>/`:

| File | Contents |
| --- | --- |
| `instability-bench-output.txt` | Console output, including the per-query table and the summary totals |
| `mariposa_summary.csv` | One row per query: `unsat_count`, `unknown_count`, `timeout_count`, `status`, `elapsed_sec` |
| `mariposa_res.csv` | Per-mutant results for the last query only |
| `mariposa-logs/` | One mariposa log per query (`mariposa_run_<i>.log`) |
| `META.txt` | Host, core count, Z3 and mariposa-slim versions, arguments, start/end times and exit status |

## Running tools by hand

To call Z3, mariposa or the bench wrappers yourself, first run
`source setup/env.sh`. This exports `Z3_BIN`, `MARIPOSA_SLIM_DIR`,
`MARIPOSA_PYTHON` and `MARIPOSA_WRAPPER`.
