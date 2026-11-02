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

`deps/`, `results/` and the downloaded benchmarks are git-ignored.

# Quick start

```sh
setup/setup-all.sh                    # install deps + fetch benchmarks (once)
experiments/mariposa-instability.sh   # run the instability experiment
```

# Prerequisites

- `git`, `make`, a C++ compiler, `python3` with `venv`, and `cargo` (Rust).
  `setup-all.sh` checks for these first and exits if one is missing.
- Read access to the private repo
  [Z3Prover/bench](https://github.com/Z3Prover/bench). It is used to fetch both the
  benchmarks and the experiment driver scripts. By default it is cloned over SSH,
  so you need a GitHub SSH key with access. To use HTTPS (e.g. with `gh auth`
  credentials), set:
  ```sh
  export BENCH_REPO_URL=https://github.com/Z3Prover/bench.git
  ```

# Setup

`setup/setup-all.sh` runs the steps below in order. Every step is safe to re-run:
checkouts that are already at the pinned commit are skipped. You can also run any
step on its own.

| Script | What it does |
| --- | --- |
| `setup/install-z3.sh [jobs]` | Builds Z3 into `deps/z3/build/z3`. `jobs` defaults to `nproc`. |
| `setup/install-mariposa-slim.sh` | Checks out [mariposa-slim](https://github.com/CanCebeci/mariposa-slim) into `deps/mariposa-slim`, points its `z3_local` solver at the Z3 built above, adds the `default_48procs` experiment config (see below), builds `smt2action` with cargo, and creates a Python venv in `deps/venv` from `setup/requirements.txt`. |
| `setup/fetch-bench-scripts.sh` | Copies the driver scripts (`instability-bench.sh`, `mariposa-wrappers/`) from Z3Prover/bench into `deps/bench-scripts`, then patches them (see below). |
| `setup/fetch-benchmarks.sh [--force]` | Runs every script in `benchmarks/fetch-scripts/`. `--force` re-downloads benchmarks that are already there. |

## Patches to the upstream driver scripts

`fetch-bench-scripts.sh` makes two changes to the copied scripts:

- `run_mariposa.sh` hardcodes `~/mariposa-slim`. The copy uses
  `$MARIPOSA_SLIM_DIR` (i.e. `deps/mariposa-slim`) instead.
- `get_csv.sh` uses the `sqlite3` CLI when it is installed. That writes CSV output
  in a format `instability-bench.sh` doesn't parse, so every count comes out as 0.
  The copy always uses the Python fallback, which is what the counting expects.

## Pinned versions and overrides

The versions are set in `setup/common.sh`. To use a different version, set the
matching environment variable when you run the setup scripts:

| Variable | Default |
| --- | --- |
| `Z3_REPO_URL`, `Z3_COMMIT` | `Z3Prover/z3` @ `30c74fcc` |
| `MARIPOSA_REPO_URL`, `MARIPOSA_COMMIT` | `CanCebeci/mariposa-slim` @ `79ec55b7` |
| `BENCH_REPO_URL`, `BENCH_COMMIT` | `Z3Prover/bench` (SSH) @ `f4446738` |
| `DEPS_DIR` | `deps/` |

For example, `Z3_COMMIT=<sha> setup/install-z3.sh` builds another Z3 version.
`deps/z3` holds one Z3 checkout at a time, so this replaces the existing build.
The benchmark fetch script reads `BENCH_REPO_URL` and `BENCH_COMMIT` as well.

The Python packages in `setup/requirements.txt` are unpinned, as in the upstream
workflow. That file lists the versions the reference run had.

# Benchmarks

| Benchmark | Fetch script | Contents |
| --- | --- | --- |
| `benchmarks/mariposa-unsat-core/` | `fetch-mariposa-unsat-core.sh` | 58 `.smt2` queries (~280 MB) from `inputs/mariposa/unstable_core` in Z3Prover/bench. This is the workflow's default benchmark. |

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
| `META.txt` | Host, core count, Z3/mariposa/bench-scripts versions, arguments, start/end times and exit status |

## Running tools by hand

To call Z3, mariposa or the bench wrappers yourself, first run
`source setup/env.sh`. This exports `Z3_BIN`, `MARIPOSA_SLIM_DIR`,
`MARIPOSA_PYTHON` and `MARIPOSA_WRAPPER`.
