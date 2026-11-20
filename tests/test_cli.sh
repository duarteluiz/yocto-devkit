#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

check() { printf '[test] %s\n' "$*"; }

check 'Checking Bash syntax'
bash -n "$ROOT/bin/yocto-devkit"
bash -n "$ROOT/scripts/container-init.sh"

check 'Checking CLI help'
"$ROOT/bin/yocto-devkit" help >"$TEMP_DIR/help.txt"
grep -q 'setup' "$TEMP_DIR/help.txt"
grep -q 'bitbake' "$TEMP_DIR/help.txt"

check 'Checking unknown command rejection'
if "$ROOT/bin/yocto-devkit" does-not-exist >"$TEMP_DIR/invalid.log" 2>&1; then
  printf 'Unknown command was accepted\n' >&2
  exit 1
fi

check 'Checking Dockerfile and Yocto metadata'
grep -q 'FROM ubuntu:24.04' "$ROOT/docker/Dockerfile"
grep -q 'LAYERSERIES_COMPAT_devkit = "wrynose"' "$ROOT/layers/meta-devkit/conf/layer.conf"
# shellcheck disable=SC2016 # Matching a literal BitBake variable expression.
grep -q 'S = "${UNPACKDIR}"' "$ROOT/layers/meta-devkit/recipes-examples/hello-yocto/hello-yocto_1.0.bb"

check 'Compiling the standalone C++ sample'
if command -v g++ >/dev/null 2>&1; then
  g++ -std=c++17 -Wall -Wextra -Werror \
    "$ROOT/layers/meta-devkit/recipes-examples/hello-yocto/files/main.cpp" \
    -o "$TEMP_DIR/hello-yocto"
  "$TEMP_DIR/hello-yocto" | grep -q 'Hello from a C++ application built with Yocto!'
else
  check 'g++ unavailable; skipping standalone compilation'
fi

if command -v shellcheck >/dev/null 2>&1; then
  check 'Running ShellCheck'
  shellcheck "$ROOT/bin/yocto-devkit" "$ROOT/scripts/container-init.sh" "$ROOT/tests/test_cli.sh"
fi

check 'All lightweight tests passed'
