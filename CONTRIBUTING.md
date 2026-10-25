# Contributing

Thanks for helping. spinel-bundler-audit has one goal: behave like
bundler-audit 0.9.3, as a single binary compiled with Spinel. Most
changes are either a difference from bundler-audit that should not be
there, or something Spinel now compiles that used to need a workaround.

## Setup

You need a C compiler, Ruby 3.4 (building Spinel runs Ruby, and so do
the oracle scripts) and bundler-audit 0.9.3:

```sh
gem install bundler-audit -v 0.9.3
.github/scripts/install-spinel.sh ~/.spinel   # Spinel at the commit in SPINEL_REVISION
export PATH="$HOME/.spinel/bin:$PATH"
```

## Checking a change

```sh
spin build                   # build/bin/spinel-bundler-audit
spin test                    # compiled unit tests
ruby oracle/check_tables.rb  # test tables against RubyGems, Bundler, IPAddr, JSON
oracle/run.sh                # comparison with bundler-audit 0.9.3
```

CI runs the same steps on Linux x86_64, Linux arm64 and macOS arm64
(with `ORACLE_NO_TTY=1`, since there is no terminal there). A pull request
needs all three green. [oracle/README.md](oracle/README.md) explains what
the comparison covers.

## Behavior changes

bundler-audit 0.9.3 is the reference. When fixing a difference:

- add a case to `oracle/compare.rb` that fails before the fix and passes
  after it;
- when the expected answer comes from RubyGems, Bundler, IPAddr or JSON,
  add it to the tables in `test/fixtures` so `oracle/check_tables.rb`
  confirms it against the real library;
- if the difference is meant to stay, list it under "Known differences"
  in the README.

Problems with the advisories themselves (a missing CVE, a wrong patched
version) belong to [ruby-advisory-db](https://github.com/rubysec/ruby-advisory-db).

## Code

The code is plain Ruby that Spinel compiles ahead of time, following the
`spin` package layout: `spinel_bundler_audit.rb` and
`spinel_bundler_audit/` at the root, the executable in `bin/`, compiled
tests with their `.expected` output in `test/` (`spin test --regen`
rewrites them).

Spinel covers a large part of Ruby, not all of it. When it refuses
something, write the plain form it accepts and leave a short comment
saying why. When a newer Spinel lifts the limit, the workaround can go:
update `SPINEL_REVISION` in its own commit.

## Commits and pull requests

Small commits, each one a single change that builds and passes. The
title states what is now true, in the present tense, and names the
mechanism ("GEM remotes are listed in Bundler's order"), not the task
("Fix remotes"). Put the why in the body when it isn't obvious.
