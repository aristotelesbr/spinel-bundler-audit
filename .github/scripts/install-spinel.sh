#!/usr/bin/env bash
# Builds Spinel at the commit in SPINEL_REVISION and installs it in $1
# (default ~/.spinel). Prism and RBS come from `make deps`; the build itself
# runs Ruby, so Ruby has to be on PATH first.
set -euo pipefail

prefix=${1:-$HOME/.spinel}
revision=$(cat SPINEL_REVISION)
src=$(mktemp -d)

git clone --quiet https://github.com/matz/spinel.git "$src"
git -C "$src" checkout --quiet "$revision"
make -C "$src" deps
make -C "$src" -j"$(getconf _NPROCESSORS_ONLN)" all
make -C "$src" install PREFIX="$prefix"
"$prefix/bin/spinel" --version
