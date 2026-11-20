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
grep -q 'safety-check' "$TEMP_DIR/help.txt"

check 'Rejecting unsafe workspace paths'
for unsafe in / /boot /etc /tmp/../boot; do
  if YOCTO_DEVKIT_WORKSPACE="$unsafe" "$ROOT/bin/yocto-devkit" safety-check >"$TEMP_DIR/unsafe.log" 2>&1; then
    printf 'Unsafe workspace accepted: %s\n' "$unsafe" >&2
    exit 1
  fi
done

check 'Checking unknown command rejection'
if "$ROOT/bin/yocto-devkit" does-not-exist >"$TEMP_DIR/invalid.log" 2>&1; then
  printf 'Unknown command was accepted\n' >&2
  exit 1
fi

check 'Checking QEMU stdin and terminal forwarding'
# This regression test requires no Docker daemon or Yocto build. The mock
# records the docker run arguments from a pseudo-terminal invocation.
mkdir -p "$TEMP_DIR/mock-bin" "$TEMP_DIR/workspace/build/conf"
: > "$TEMP_DIR/workspace/build/conf/local.conf"
cat > "$TEMP_DIR/mock-bin/docker" <<'MOCK_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  info) exit 0 ;;
  image) [[ "${2:-}" == inspect ]] ;;
  run) printf '%s\n' "$@" > "${MOCK_DOCKER_ARGS:?}" ;;
  *) exit 1 ;;
esac
MOCK_DOCKER
chmod +x "$TEMP_DIR/mock-bin/docker"
if ! command -v script >/dev/null 2>&1; then
  printf 'script(1) is required for pseudo-terminal regression tests\n' >&2
  exit 1
fi
env PATH="$TEMP_DIR/mock-bin:$PATH" \
  YOCTO_DEVKIT_WORKSPACE="$TEMP_DIR/workspace" \
  MOCK_DOCKER_ARGS="$TEMP_DIR/docker-args" \
  script -q -e -c "$ROOT/bin/yocto-devkit run" /dev/null >"$TEMP_DIR/qemu-run.log" 2>&1
grep -Fxq -- '-it' "$TEMP_DIR/docker-args" || {
  printf 'QEMU Docker invocation omitted -it\n' >&2
  exit 1
}
grep -Fxq -- 'run' "$TEMP_DIR/docker-args"

check 'Checking non-interactive actions do not allocate a TTY'
env PATH="$TEMP_DIR/mock-bin:$PATH" \
  YOCTO_DEVKIT_WORKSPACE="$TEMP_DIR/workspace" \
  MOCK_DOCKER_ARGS="$TEMP_DIR/docker-args" \
  "$ROOT/bin/yocto-devkit" debug status >"$TEMP_DIR/debug-status.log" 2>&1
if grep -Fxq -- '-it' "$TEMP_DIR/docker-args"; then
  printf 'Non-interactive Docker invocation incorrectly uses -it\n' >&2
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
