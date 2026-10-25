#!/usr/bin/env bash
# Downloads the Gemfile and Gemfile.lock of each app in oracle/APPS
# ("name owner/repository commit" per line) into tmp/apps/<name>/. Only
# those two files are fetched; nothing of the apps goes into this repository.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

while read -r name repository commit; do
  dir=$root/tmp/apps/$name
  [ "$(cat "$dir/.commit" 2>/dev/null)" = "$commit" ] && continue

  rm -rf "$dir"
  mkdir -p "$dir"
  for file in Gemfile Gemfile.lock; do
    curl -fsSL "https://raw.githubusercontent.com/$repository/$commit/$file" -o "$dir/$file"
  done
  echo "$commit" > "$dir/.commit"
done < "$root/oracle/APPS"
