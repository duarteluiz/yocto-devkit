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
grep -q 'debug enable' "$TEMP_DIR/help.txt"
grep -q 'cpp-test' "$TEMP_DIR/help.txt"

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

check 'Checking C++ dependencies and opt-in debug metadata'
grep -q 'catch2 libfmt-dev libspdlog-dev' "$ROOT/docker/Dockerfile"
grep -q 'clone_repo meta-openembedded' "$ROOT/scripts/container-init.sh"
grep -q 'tools-debug dbg-pkgs dev-pkgs' "$ROOT/scripts/container-init.sh"
grep -q 'DEPENDS = "catch2 fmt spdlog"' "$ROOT/layers/meta-devkit/recipes-test/devkit-cpp-tests/devkit-cpp-tests_1.0.bb"

check 'Compiling the standalone C++ sample'
if command -v g++ >/dev/null 2>&1; then
  g++ -std=c++17 -Wall -Wextra -Werror \
    "$ROOT/layers/meta-devkit/recipes-examples/hello-yocto/files/main.cpp" \
    -o "$TEMP_DIR/hello-yocto"
  "$TEMP_DIR/hello-yocto" | grep -q 'Hello from a C++ application built with Yocto!'
else
  check 'g++ unavailable; skipping standalone compilation'
fi

if command -v cmake >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1 && \
   test -f /usr/include/catch2/catch_test_macros.hpp && \
   test -d /usr/lib/x86_64-linux-gnu/cmake/fmt; then
  check 'Compiling and running Catch2/fmt/spdlog tests'
  cmake -S "$ROOT/layers/meta-devkit/recipes-test/devkit-cpp-tests/files" \
    -B "$TEMP_DIR/cpp-build" -G Ninja -DCMAKE_BUILD_TYPE=Debug
  cmake --build "$TEMP_DIR/cpp-build" --parallel 2
  ctest --test-dir "$TEMP_DIR/cpp-build" --output-on-failure
else
  check 'Native Catch2 dependencies not installed; Docker smoke CI covers these tests'
fi

if command -v shellcheck >/dev/null 2>&1; then
  check 'Running ShellCheck'
  shellcheck "$ROOT/bin/yocto-devkit" "$ROOT/scripts/container-init.sh" "$ROOT/tests/test_cli.sh"
fi

check 'All lightweight tests passed'
