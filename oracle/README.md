# Oracle

spinel-bundler-audit aims to behave like bundler-audit 0.9.3. The scripts
here check that claim against the real thing instead of against
expectations written by hand.

There are two checks:

- **`check_tables.rb`** runs the case tables in `test/fixtures` through the
  libraries bundler-audit relies on (RubyGems, Bundler, IPAddr, JSON) under
  CRuby, so every answer the unit tests expect comes from those libraries.
- **`compare.rb`** runs bundler-audit and the compiled binary on the same
  cases and compares stdout, stderr and exit status byte for byte.

## Running

```sh
gem install bundler-audit -v 0.9.3
spin build

ruby oracle/check_tables.rb
oracle/run.sh                    # all cases
ORACLE_NO_TTY=1 oracle/run.sh    # without the terminal cases, as CI runs it
```

`oracle/run.sh` checks out ruby-advisory-db at the pinned commit, downloads
the app lockfiles and runs `compare.rb`. Everything it writes goes under
`tmp/`. Each case that differs is reported as it runs, with the first
line where the outputs part; the run ends with the number of identical
cases and exits 1 if any differs.

## Files

| File | What it holds |
|---|---|
| `check_tables.rb` | The table check above |
| `compare.rb` | The cases and the comparison |
| `run.sh` | Prepares the pinned inputs and runs `compare.rb` |
| `DB_REVISION` | The ruby-advisory-db commit both tools read |
| `APPS` | Open-source Rails apps, one `name owner/repository commit` per line |
| `fetch-apps.sh` | Downloads only the `Gemfile` and `Gemfile.lock` of each app into `tmp/apps/` |

The pinned inputs keep the results reproducible: anyone running the
oracle at a given commit of this repository compares the same database
and the same lockfiles.

## What `compare.rb` covers

1. **Version boundaries.** For every gem in the database, lockfiles at
   the versions its advisories name and at the versions next to them,
   where range mistakes show up.
2. **Formats and options** (text, json, junit, verbose, quiet, output
   file) on a sample of those lockfiles.
3. **Terminal output**: colors and pretty JSON, run through `script(1)`.
4. **Ignore lists**, from the command line and from `.bundler-audit.yml`.
5. **Lockfile shapes**: GIT and PATH sources, insecure and internal
   remotes, checksums, prerelease versions, unsorted specs.
6. **Command line**: defaults, command prefixes, errors.
7. **Database maintenance** (`update`, `download`, `check --update`) on
   local copies, so nothing touches the network.
8. **Real lockfiles**: the apps in `APPS`.

Output that is meant to differ is normalized first: the tool's name and
version, timestamps, and the JUnit suite id.

Option parsing is a documented difference: spinel-bundler-audit uses
`optparse`. Cases that depend on it, such as an unknown option, check
the binary's own answer instead of comparing it with bundler-audit.
