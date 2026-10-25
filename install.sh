#!/bin/sh
# Installs a spinel-bundler-audit release, checked against its SHA256SUMS:
#
#   curl -fsSL https://raw.githubusercontent.com/aristotelesbr/spinel-bundler-audit/main/install.sh | sh
#
# VERSION picks a release (default: the latest), INSTALL_DIR the directory
# (default: ~/.local/bin), RELEASES another place to download from.
set -eu

releases=${RELEASES:-https://github.com/aristotelesbr/spinel-bundler-audit/releases}
dir=${INSTALL_DIR:-$HOME/.local/bin}

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform=linux-x86_64 ;;
  Linux-aarch64 | Linux-arm64) platform=linux-arm64 ;;
  Darwin-arm64) platform=macos-arm64 ;;
  *)
    echo "No prebuilt spinel-bundler-audit for $(uname -s) $(uname -m)." >&2
    exit 1
    ;;
esac

if [ -z "${VERSION:-}" ]; then
  latest=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$releases/latest")
  VERSION=${latest##*/v}
fi

name=spinel-bundler-audit-$VERSION-$platform
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

curl -fsSLO "$releases/download/v$VERSION/$name.tar.gz"
curl -fsSLO "$releases/download/v$VERSION/SHA256SUMS"
if command -v sha256sum > /dev/null; then
  sum=sha256sum
else
  sum="shasum -a 256"
fi
grep " $name.tar.gz\$" SHA256SUMS | $sum -c - > /dev/null 2>&1 || {
  echo "$name.tar.gz does not match SHA256SUMS." >&2
  exit 1
}

tar xzf "$name.tar.gz"
mkdir -p "$dir"
install -m 755 "$name/spinel-bundler-audit" "$dir/spinel-bundler-audit"
echo "Installed spinel-bundler-audit $VERSION in $dir."
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "Add $dir to your PATH to run it." ;;
esac
