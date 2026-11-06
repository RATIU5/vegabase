#!/bin/sh
set -eu
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case $arch in
aarch64) arch=arm64 ;;
x86_64) arch=amd64 ;;
esac
mkdir -p dist
exec odin build source -out:"dist/vegabase-$os-$arch" -vet -strict-style
