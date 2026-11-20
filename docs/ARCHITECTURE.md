# Architecture and design decisions

## Scope

Yocto DevKit is a development **environment bootstrap**, not a Yocto fork or a BSP for production hardware. It owns the Docker build-host, a portable command-line entry point, a demo layer and local initialization; upstream BitBake, OE-Core and Poky metadata remain separate checkouts in a user-controlled workspace.

## Components

| Component | Responsibility |
| --- | --- |
| `bin/yocto-devkit` | Checks prerequisites, initializes workspace, orchestrates Docker and displays progress |
| `docker/Dockerfile` | Installs packages listed in Yocto 6.0 Ubuntu build-host documentation |
| `scripts/container-init.sh` | Fetches upstream sources, initializes BitBake, manages a local configuration block, runs commands |
| `layers/meta-devkit` | Holds the C++ demonstration recipe; mounted read-only into containers |
| `tests/test_cli.sh` | Non-destructive static/behavioral tests, independent of Docker or a full Yocto build |

## Workflow

1. Check exact host distribution and architecture.
2. Create a persistent, bind-mounted workspace and assess free disk/memory.
3. Resolve usable Docker access; install Ubuntu `docker.io` only with explicit permission.
4. Build or refresh the Ubuntu 24.04 development image using Docker cache.
5. Clone four repositories into the workspace: BitBake, OE-Core, meta-yocto and meta-openembedded.
6. Initialize the build shell with `openembedded-core/oe-init-build-env`.
7. Add the Poky distro layer, meta-oe and the custom DevKit layer.
8. Append managed `local.conf` configuration and verify BitBake.
9. On demand, build `core-image-minimal` and boot using `runqemu`.

## Idempotency

Existing valid clones remain checked out at their current commits. Existing generated `local.conf` and `bblayers.conf` are preserved, with only missing layer entries added. The managed configuration block is appended once; an independent debug block allows opt-in symbol and tool installation. The installer uses a dedicated clone staging directory and retries transient failures. It does not automatically upgrade upstream Git repositories or remove Yocto caches.

For exact repeatability, pin the SHA of **each** of the four upstream repositories, plus the Docker image digest and the DevKit revision, in your own release process. The starter clones moving `yocto-6.0` branches only on the first setup.

## Docker and QEMU

The development container runs under the host user's UID/GID, while Docker itself may need sudo privileges. The host workspace is writable; the bundled metadata layer is mounted read-only. Container privileges are reduced. For QEMU, `/dev/kvm` is exposed only when the invoking host user already has read/write permissions. In other cases the emulator falls back to software acceleration.

QEMU uses `snapshot`, `nographic` and `slirp`: guest changes are disposable, console access is terminal-based, and user-mode networking avoids host TAP bridge configuration. The container does not publish public TCP ports. If you need SSH into the VM, design an explicit Docker port mapping and review guest authentication; the baseline does not promise host-to-guest SSH access.

## Limitations

- The starter supports Ubuntu 24.04 on x86-64 only.
- Only the `qemux86-64` workflow is validated by the initial configuration.
- A full Yocto build is not feasible in the lightweight CI job.
- Automated fallback to a completely different upstream release is intentionally avoided: such a fallback could silently mix incompatible layers.
- Docker engine installation may require a working Ubuntu apt mirror and administrative privileges.
- The example image contains intentionally insecure login settings for experimentation. The optional debug profile additionally adds debug tools/symbols and a C++ test runner, which must not be included in a production image.
