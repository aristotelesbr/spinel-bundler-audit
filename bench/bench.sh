#!/usr/bin/env bash
# Times bundler-audit 0.9.3 against spinel-bundler-audit with hyperfine.
# Run on an idle machine; results go to tmp/bench/.
#
#   bench/bench.sh                # needs oracle/run.sh to have prepared tmp/
#   APP=path/to/app bench/bench.sh  # also a local app
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/tmp/bench
bin=$root/build/bin/spinel-bundler-audit
cases=$root/tmp/cases
export BUNDLER_AUDIT_DB=$root/tmp/ruby-advisory-db
export XDG_CACHE_HOME=$root/tmp/cache
mkdir -p "$out"
"$root/oracle/fetch-apps.sh"

# Build the index once, outside the timings.
(cd "$cases" && "$bin" check -G clean.lock > /dev/null || true)

run() {
  local name=$1 dir=$2
  shift 2
  echo "== $name: check $*"
  (cd "$dir" && hyperfine -N -i --warmup 3 --runs "${RUNS:-50}" \
    --export-markdown "$out/$name.md" --export-json "$out/$name.json" \
    -n bundler-audit "bundle-audit check --no-update $*" \
    -n spinel-bundler-audit "$bin check $*")
}

for name in $(cut -d' ' -f1 "$root/oracle/APPS"); do
  run "$name" "$root/tmp/apps/$name"
done
if [ -n "${APP:-}" ]; then
  run app "$APP"
fi
run clean "$cases" -G clean.lock
run heavy "$cases" -G boundary-000.lock
run heavy-json "$cases" -G boundary-000.lock -F json
