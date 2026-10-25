#!/usr/bin/env bash
# Compares build/bin/spinel-bundler-audit with bundler-audit 0.9.3 on the
# ruby-advisory-db commit in oracle/DB_REVISION.
#
#   oracle/run.sh                    # all cases
#   ORACLE_NO_TTY=1 oracle/run.sh    # without the terminal cases (CI)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
db=$root/tmp/ruby-advisory-db
revision=$(cat "$root/oracle/DB_REVISION")

if [ ! -d "$db/.git" ]; then
  git clone --quiet https://github.com/rubysec/ruby-advisory-db.git "$db"
fi
git -C "$db" cat-file -e "$revision^{commit}" 2>/dev/null || git -C "$db" fetch --quiet origin
git -C "$db" checkout --quiet "$revision"

bundle-audit version | grep -q "bundler-audit 0.9.3" || {
  echo "oracle/run.sh needs bundler-audit 0.9.3 (gem install bundler-audit -v 0.9.3)" >&2
  exit 1
}

ORACLE_DB=$db ruby "$root/oracle/compare.rb"
