#!/bin/sh
set -eu
os=$(uname -s)
arch=$(uname -m)
case $os in
  Darwin) target=darwin ;;
  Linux) target=unknown-linux-gnu ;;
  *) echo "Unsupported OS: $os" >&2; exit 1 ;;
esac
case $arch in
  arm64|aarch64) arch=arm64 ;;
esac
exec "odinfmt-$arch-$target" "$@"
