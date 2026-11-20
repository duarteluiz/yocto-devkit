#!/usr/bin/env bash
# Commands executed as an unprivileged user within the development container.
set -Eeuo pipefail

readonly ROOT=/workspace
readonly LAYERS="$ROOT/sources/layers"
readonly CORE="$LAYERS/openembedded-core"
readonly BUILD="$ROOT/build"
readonly BRANCH=yocto-6.0

info() { printf '[container] %s\n' "$*"; }
fail() { printf '[container] ERROR: %s\n' "$*" >&2; exit 1; }

retry() {
  local tries=0
  until "$@"; do
    tries=$((tries + 1))
    (( tries < 3 )) || return 1
    info "Attempt $tries failed; retrying..."
    sleep "$((tries * 3))"
  done
}

clone_repo() {
  local name=$1 url=$2 dest="$LAYERS/$1" stage
  if [[ -d "$dest/.git" ]]; then
    info "$name already exists; preserving its checked-out revision."
    return 0
  fi
  [[ ! -e "$dest" ]] || fail "$dest exists but is not a Git checkout; refusing to overwrite it."
  stage="$LAYERS/.${name}.clone-partial"
  rm -rf -- "$stage"  # Only our known, generated staging directory.
  retry git -c http.version=HTTP/1.1 clone --depth 1 --branch "$BRANCH" "$url" "$stage" || \
    fail "Could not clone $name from $url. Check proxy, DNS and network access."
  mv -- "$stage" "$dest"
  git -C "$dest" rev-parse HEAD
}

fetch_sources() {
  mkdir -p "$LAYERS" "$ROOT/cache/downloads" "$ROOT/cache/sstate" "$ROOT/home"
  clone_repo bitbake https://git.openembedded.org/bitbake
  clone_repo openembedded-core https://git.openembedded.org/openembedded-core
  clone_repo meta-yocto https://git.yoctoproject.org/meta-yocto
  info 'All source repositories are available.'
}

activate() {
  [[ -f "$CORE/oe-init-build-env" ]] || fail 'Missing OE-Core setup script; run setup first.'
  export PATH="$LAYERS/bitbake/bin:$PATH"
  # The setup script changes directory into the build tree; disable nounset only
  # while sourcing this upstream Bash script, which may reference unset variables.
  set +u
  # shellcheck disable=SC1091
  source "$CORE/oe-init-build-env" "$BUILD" >/dev/null
  set -u
  export PATH="$LAYERS/bitbake/bin:$PATH"
}

append_managed_config() {
  local conf="$BUILD/conf/local.conf" cpu mem threads
  [[ -f "$conf" ]] || fail "Configuration file not found: $conf"
  if grep -q '^# BEGIN YOCTO-DEVKIT' "$conf"; then
    info 'Managed local.conf block already exists; leaving user configuration intact.'
    return 0
  fi
  cpu="$(nproc)"
  mem="$(awk '/MemTotal:/ {print int($2/1024/1024)}' /proc/meminfo)"
  threads=$((mem / 3))
  (( threads >= 1 )) || threads=1
  (( threads <= cpu )) || threads=$cpu
  (( threads <= 8 )) || threads=8
  cat >>"$conf" <<CONFIG

# BEGIN YOCTO-DEVKIT (development-only settings; do not ship to production)
MACHINE = "qemux86-64"
DISTRO = "poky"
DL_DIR = "/workspace/cache/downloads"
SSTATE_DIR = "/workspace/cache/sstate"
BB_NUMBER_THREADS = "$threads"
PARALLEL_MAKE = "-j $threads"
IMAGE_INSTALL:append = " hello-yocto"
# WARNING: passwordless root login is for the isolated test VM ONLY.
IMAGE_FEATURES:append = " allow-empty-password allow-root-login empty-root-password"
# END YOCTO-DEVKIT
CONFIG
  info "Configured $threads parallel build tasks."
}

configure() {
  activate
  local meta_poky="$LAYERS/meta-yocto/meta-poky"
  [[ -f "$meta_poky/conf/layer.conf" ]] || fail 'meta-poky layer is missing.'
  [[ -f /opt/devkit/meta-devkit/conf/layer.conf ]] || fail 'DevKit example layer not mounted.'
  if ! grep -Fq "$meta_poky" "$BUILD/conf/bblayers.conf"; then
    bitbake-layers add-layer "$meta_poky"
  fi
  if ! grep -Fq '/opt/devkit/meta-devkit' "$BUILD/conf/bblayers.conf"; then
    bitbake-layers add-layer /opt/devkit/meta-devkit
  fi
  append_managed_config
  info 'Yocto configuration ready.'
}

verify() {
  activate
  command -v bitbake >/dev/null || fail 'BitBake not found in PATH.'
  bitbake --version
  bitbake-layers show-layers
  bitbake -p
  [[ -s "$BUILD/conf/bblayers.conf" ]] || fail 'bblayers.conf was not generated.'
  [[ -s "$BUILD/conf/local.conf" ]] || fail 'local.conf was not generated.'
  info 'Workspace verification passed.'
}

main() {
  local action=${1:-help}; (( $# == 0 )) || shift
  case "$action" in
    fetch) fetch_sources ;;
    configure) configure ;;
    verify) verify ;;
    build) activate; bitbake "${1:-core-image-minimal}" ;;
    run)
      local target=${1:-core-image-minimal}
      activate
      [[ -d "$BUILD/tmp/deploy/images/qemux86-64" ]] || fail 'No image deployed. Build first.'
      local options=(qemux86-64 "$target" snapshot nographic slirp)
      if [[ -r /dev/kvm && -w /dev/kvm ]]; then options+=(kvm); fi
      exec runqemu "${options[@]}"
      ;;
    shell) activate; exec bash --noprofile --norc -i ;;
    bitbake) activate; bitbake "$@" ;;
    help) printf 'Supported commands: fetch configure verify build run shell bitbake\n' ;;
    *) fail "Unknown container action: $action" ;;
  esac
}
main "$@"
