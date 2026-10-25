# Benchmark

How spinel-bundler-audit compares with bundler-audit 0.9.3 in time and
memory, measured so that anyone can repeat it and get comparable numbers.
The oracle ([oracle/README.md](../oracle/README.md)) answers whether both
print the same thing; this answers how long and how much memory it takes.

## Running it

```sh
gem install bundler-audit -v 0.9.3   # and hyperfine 2.0 or newer
oracle/run.sh                        # prepares tmp/: database, lockfiles, apps
ruby bench/experiment.rb             # about 5 minutes on an idle machine
```

Results go to `tmp/bench/<date>-<machine>/RESULTS.md`, with every raw file
next to it. Close what you can first: timings taken while the machine is
busy are noise.

`VERSION` picks the release to download (default `0.1.0`), `BINARY` measures
a local executable instead, `ROUNDS` and `RUNS` change the repetitions
(default 3 and 50). Each step can also run on its own; the comment at the
top of `experiment.rb` lists them.

## What it does

1. **Prepare.** Downloads the release binary for this platform and checks
   it against the release's `SHA256SUMS`, so the numbers describe what users
   install. Records the machine, the versions, the database commit and the
   SHA-256 of every lockfile measured.
2. **Equivalence.** Runs both tools once on every case and stops if stdout,
   stderr or the exit status differ. Timing tools that do different work
   would compare nothing.
3. **Measure.** hyperfine, 5 warmup runs and 50 measured runs per command,
   in 3 rounds. The tool that runs first alternates between rounds, so
   thermal or load drift does not favor either. hyperfine 2.0 records wall
   time, peak memory and instructions for every run.
4. **Check.** Every run must have exited with the status the equivalence
   step saw (0 for a clean lockfile, 1 when advisories are found). hyperfine
   runs with `-i` because 1 is the expected answer, and this step makes sure
   no failure hid behind it.
5. **Analyze.** Medians and interquartile ranges over all rounds, the
   median of each round, and the ratio of medians with a 95% confidence
   interval by bootstrap (10,000 resamples, fixed seed). Instructions vary
   little with load, so they confirm that a time difference is real.

## Cases

| Case | Lockfile | Gems | Advisories |
|---|---|---:|---:|
| clean | one gem that has no advisory (startup cost) | 1 | 0 |
| mastodon, discourse, forem | the apps in [oracle/APPS](../oracle/APPS), at pinned commits | 345, 344, 438 | 1, 1, 40 |
| synthetic | `boundary-000.lock` from `oracle/compare.rb`: many gems that all have advisories | 473 | 959 |
| forem-json | forem with `-F json` | 438 | 40 |
| first-run | mastodon with the index removed before every run (spinel-bundler-audit only) | 345 | 1 |

bundler-audit runs as `bundle-audit check --no-update`, without
`bundle exec`, its cheapest form; spinel-bundler-audit as `check`. Both read
the same database, ruby-advisory-db at [oracle/DB_REVISION](../oracle/DB_REVISION).

## Results

Each directory under [results/](results/) is one run, with its raw hyperfine
files. `ruby bench/experiment.rb analyze bench/results/<dir>` recomputes its
`RESULTS.md`, and `check` re-verifies its exit statuses, without measuring
anything.

| Run | Machine |
|---|---|
| [2026-10-25-apple-m3-pro](results/2026-10-25-apple-m3-pro/RESULTS.md) | Apple M3 Pro, macOS 27, v0.1.0 release binary |

A run on another machine, especially Linux, is welcome as a pull request
that adds its directory.

## Optional: output tokens

`ruby bench/experiment.rb tokens` counts the tokens of each case's output
with tiktoken's `o200k_base` (`pip install tiktoken`), as an approximation
of what a coding agent reads. With identical output the counts are
identical; the step is there to show it.

## Limits

- One machine per results directory. A laptop is not a CI runner.
- The disk cache is warm for both tools. A CI job without a cache also
  reads the advisory files from a cold disk.
- The authors of this tool wrote the benchmark. The raw files are here so
  that the analysis can be checked, and the script so that the
  measurement can be repeated.
