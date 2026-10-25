# spinel-bundler-audit

A standalone alternative to [bundler-audit](https://github.com/rubysec/bundler-audit),
compiled with [Spinel](https://github.com/matz/spinel) into a single native
executable.

It is not affiliated with RubySec or the bundler-audit authors. It reads the
same [ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db) and aims
to behave like bundler-audit 0.9.3: same commands, options, output and exit
status.

## Install

macOS (Apple Silicon) and Linux (x86_64, arm64):

```sh
curl -fsSL https://raw.githubusercontent.com/aristotelesbr/spinel-bundler-audit/main/install.sh | sh
```

The script picks the build for your machine, checks it against the
release's `SHA256SUMS` and installs it in `~/.local/bin` (set
`INSTALL_DIR` or `VERSION` to change that). No Ruby needed. It runs on
macOS 11 or newer, and on Linux with glibc 2.34 or newer (Ubuntu 22.04,
Debian 12, RHEL 9, Amazon Linux 2023 and later). The archives are on the
[releases page](https://github.com/aristotelesbr/spinel-bundler-audit/releases).

### In CI or from a coding agent

The same command runs unattended and prints a line or two. Update the
database once, then check as often as needed:

```sh
spinel-bundler-audit update
spinel-bundler-audit check
```

When an agent reads the report, keep the default text format: the json
report of the same lockfile is about four times as many tokens.

## Usage

The commands are bundler-audit's:

```sh
spinel-bundler-audit check            # audit ./Gemfile.lock
spinel-bundler-audit check --update   # update the advisory database first
spinel-bundler-audit check -F json -o report.json
spinel-bundler-audit update
spinel-bundler-audit stats
```

In CI:

```yaml
- run: spinel-bundler-audit check --update
```

The advisory database lives where bundler-audit keeps it
(`~/.local/share/ruby-advisory-db`, or `BUNDLER_AUDIT_DB`), and
`.bundler-audit.yml` is read the same way, so both tools can share one
setup.

## Compatibility

The same as bundler-audit 0.9.3: commands (`check`, `update`, `download`,
`stats`, `version`), options, the text, json and junit formats, exit
status, error messages, `.bundler-audit.yml` and `BUNDLER_AUDIT_DB`.
Every release is checked case by case against bundler-audit 0.9.3;
[oracle/](oracle/README.md) explains how.

Known differences:

- Options are read with `optparse`: an unknown option is an error (bundler-audit
  takes it as the directory), an attached short value works (`-Gfile`), long
  options can be abbreviated, and a missing value prints optparse's message.
  `--ignore CVE-1 CVE-2` works as in bundler-audit.
- `version` and `help` print this tool's name and text.
- An invalid `.bundler-audit.yml` exits with its message; bundler-audit
  prints a backtrace.
- Internal source hosts are resolved with the system resolver instead of
  Ruby's `Resolv`.
- There is no Rake task and no `tree` command.

## Advisory index

Instead of parsing every advisory file on each check, spinel-bundler-audit
keeps one index file per database in `~/.cache/spinel-bundler-audit/`
(`XDG_CACHE_HOME`). It is rebuilt after `update` and `download`, and on the
first check after the database moved to another git commit. A database
that is not a git checkout is read file by file, as bundler-audit does.

Limitation: an advisory file edited or added by hand without a commit is
not seen until the database commit changes. Set
`SPINEL_BUNDLER_AUDIT_NO_INDEX=1` to read the files directly.

## Development

```sh
spin build                   # build/bin/spinel-bundler-audit
spin test                    # compiled unit tests
ruby oracle/check_tables.rb  # test tables against RubyGems, Bundler, IPAddr, JSON
oracle/run.sh                # comparison with bundler-audit 0.9.3
ruby bench/experiment.rb     # time and memory against bundler-audit (bench/README.md)
```

The Spinel commit used for builds is in `SPINEL_REVISION`.

## Credits

The advisories come from [ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db),
maintained by RubySec. bundler-audit is the reference for every behavior
this tool reproduces.

## License

MIT. See `LICENSE`.
