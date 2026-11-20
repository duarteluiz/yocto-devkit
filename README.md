# Yocto DevKit

**A Docker-first, repeatable Yocto Project 6.0 LTS (Wrynose) development environment for Ubuntu 24.04.** Build custom embedded Linux images, compile C++ applications with BitBake, and boot your images with QEMU — without installing a Yocto toolchain on the host.

[![CI](https://github.com/duarteluiz/yocto-devkit/actions/workflows/ci.yml/badge.svg)](https://github.com/duarteluiz/yocto-devkit/actions/workflows/ci.yml)

> **Status:** Reference development kit. Shell checks are automated; a complete Yocto image build requires your own Ubuntu/Docker build host and has not been run in CI. This is not a production-hardened embedded Linux distribution.

## Requirements

| Component | Requirement |
| --- | --- |
| Host OS | Ubuntu 24.04 LTS, x86-64 |
| Docker | Running Docker Engine; optionally installed via `setup --install-docker` |
| Network | HTTPS access to OpenEmbedded/Yocto Git hosts and upstream source downloads |
| Disk | 140+ GiB recommended; 70 GiB is an early warning threshold |
| RAM | 32+ GiB recommended for comfortable Yocto work; lower-memory systems may run small builds slowly |
| CPU | Multi-core x86-64; KVM optional |

The host needs only Docker (and Git to clone this repository). All Yocto/C++ build-host dependencies are installed in the container, including Catch2 3, fmt, spdlog, GDB, Valgrind, Clang tools and static analyzers. Setup checks available disk, RAM, CPU, Ubuntu version, Docker daemon access, and KVM support. Low-memory systems receive automatically reduced build parallelism.

## Quick start

```bash
git clone https://github.com/duarteluiz/yocto-devkit.git
cd yocto-devkit

# Inspect prerequisites without installing anything.
./bin/yocto-devkit doctor

# Use this when Docker is already installed.
./bin/yocto-devkit setup

# Or, explicitly permit installing Docker from Ubuntu's apt repository.
./bin/yocto-devkit setup --install-docker

# Build a minimal Linux image with the included C++ example.
./bin/yocto-devkit build

# Boot in a headless QEMU guest with isolated user-mode networking.
./bin/yocto-devkit run
```

After the guest starts, log in as `root` (no password, **development image only**) and run:

```sh
hello-yocto
```

Expected output:

```text
Hello from a C++ application built with Yocto!
```

Use `Ctrl+C` in the host QEMU terminal to stop emulation. The `snapshot` option keeps guest disk changes temporary.

## Host boot and resource safety

The DevKit **does not install a bootloader, partition disks, change EFI settings, or replace the host kernel**. Yocto produces files under the workspace; QEMU boots those generated files as a guest. Docker can still affect host networking, storage and services, so review privileged operations before use.

Run `./bin/yocto-devkit doctor` for informational diagnostics or `./bin/yocto-devkit safety-check` for a **failing preflight** before a build. A build is blocked below **70 GiB of free disk** or **2 GiB of currently available RAM**. These are conservative starting thresholds, **not a guarantee** against disk exhaustion during a large build. Keep substantial additional space free and monitor `df -h` during long builds.

The workspace must be an absolute path, cannot contain symlinks or `..` components, cannot target protected system directories, and must be outside the Git checkout. Existing build output is not automatically deleted. Docker is started only when explicitly installed; it is **not enabled automatically at boot**. Existing Docker installations and their service settings are left unchanged.

QEMU runs in a container, optionally using the host's `/dev/kvm`. No `--privileged`, host networking, or host block devices are required. The development guest has an intentionally insecure passwordless root login; never use that image on real hardware or an exposed network. For greater isolation, use a dedicated non-sensitive development host and keep Ubuntu backups.

## Setup progress

The installer reports stage completion with a visible percentage bar:

```text
[==..................]  10%  Ubuntu 24.04 verified
[=======.............]  35%  Docker engine available
[============........]  60%  Development container ready
[================....]  80%  Upstream Yocto repositories ready
[====================] 100%  Setup completed successfully
```

**Percentages indicate setup milestones, not an estimate of remaining time.** Docker displays package download/build logs, Git displays clone progress, and BitBake reports its own build task progress. All setup output is saved under the workspace's `logs/` directory. A failed command exits with a diagnostic rather than claiming completion.

## Commands

| Command | Description |
| --- | --- |
| `./bin/yocto-devkit setup` | Idempotent bootstrap; reuse existing checkouts and configuration |
| `./bin/yocto-devkit setup --install-docker --yes` | Explicitly allow `apt` installation without a confirmation prompt |
| `./bin/yocto-devkit doctor` | Inspect Ubuntu, storage, memory, Docker, KVM and workspace |
| `./bin/yocto-devkit safety-check` | Enforce disk, memory and workspace guards before a build |
| `./bin/yocto-devkit build` | Build `core-image-minimal` |
| `./bin/yocto-devkit build core-image-base` | Build a named image |
| `./bin/yocto-devkit run` | Start QEMU with `snapshot nographic slirp` and optional KVM |
| `./bin/yocto-devkit shell` | Open a shell with the Yocto environment initialized |
| `./bin/yocto-devkit cpp-test` | Compile and run native Catch2/fmt/spdlog integration tests |
| `./bin/yocto-devkit debug enable` | Enable opt-in image debug symbols, headers, tools and C++ test executable |
| `./bin/yocto-devkit debug disable` | Disable the debug profile for subsequent image builds |
| `./bin/yocto-devkit debug status` | Inspect the debug profile |
| `./bin/yocto-devkit bitbake -e hello-yocto` | Pass arguments directly to BitBake |
| `./bin/yocto-devkit logs` | Print the latest setup log path |
| `./bin/yocto-devkit help` | Print the complete command reference |

Within the interactive `shell`, you can use:

```bash
bitbake-layers show-layers
bitbake-layers show-recipes hello-yocto
bitbake hello-yocto
bitbake core-image-minimal
bitbake -c cleansstate hello-yocto
```

## C++ libraries and debugging

The container installs curated **Ubuntu 24.04 packages** only, without downloading and executing unverified shell installers or using a global `pip` installation. The embedded Yocto recipes come from the `wrynose` branch of the official `meta-openembedded/meta-oe` layer.

| Area | Packages | Purpose |
| --- | --- | --- |
| Tests | `catch2` (3.x) | Modern C++ unit tests |
| Libraries | `libfmt-dev`, `libspdlog-dev`, `libboost-dev`, `nlohmann-json3-dev` | Formatting, structured logging, C++ utilities and JSON |
| Systems | `libssl-dev`, `zlib1g-dev`, `libsqlite3-dev` | TLS/cryptography, compression and embedded databases |
| Build | `cmake`, `ninja-build`, `pkg-config`, `ccache` | Repeatable compilation and build speed |
| Debug | `gdb`, `gdbserver`, `binutils`, `elfutils`, `valgrind`, `strace`, `ltrace` | Symbols, crashes, heap defects and syscall inspection |
| Quality | `clang`, `clangd`, `clang-format`, `clang-tidy`, `cppcheck`, `lcov` | Static analysis, code style and coverage |

Use `./bin/yocto-devkit cpp-test` to build and run a Catch2 sample with fmt/spdlog through CMake and CTest. For the Yocto target, `bitbake devkit-cpp-tests` cross-compiles the same sample without requiring host development libraries to be copied into the target.

The minimal image does **not** include debug symbols or debugging tools by default. Explicitly opt in when experimenting in a disposable QEMU VM:

```bash
./bin/yocto-devkit debug enable
./bin/yocto-devkit build
./bin/yocto-devkit run
# In QEMU: devkit-cpp-tests
```

The debug profile enables `tools-debug`, `dbg-pkgs` and `dev-pkgs` and installs the C++ test runner. These may greatly increase image size. Return to a leaner build using `./bin/yocto-devkit debug disable` and `./bin/yocto-devkit build`. Disabling the profile does not retroactively remove files from any already-built image. See [C++ libraries and debugging](docs/CPP_DEBUGGING.md) for GDB, sanitizers, security considerations and troubleshooting.

## Architecture

```text
Ubuntu 24.04 host
  ├── ./bin/yocto-devkit         # Setup, diagnostics, build, run and shell
  ├── Docker Engine              # Isolated Ubuntu 24.04 build-host dependencies
  └── ~/yocto-devkit-workspace/  # Persistent data, OUTSIDE the Git checkout
      ├── sources/layers/
      │   ├── bitbake/
      │   ├── openembedded-core/
      │   ├── meta-yocto/
      │   └── meta-openembedded/     # meta-oe recipes, including Catch2
      ├── build/                 # conf/, tmp/, logs/, generated images
      ├── cache/
      │   ├── downloads/         # Download cache reused between builds
      │   └── sstate/            # Shared-state cache
      ├── home/                  # Writable container HOME
      └── logs/                  # Timestamped setup logs

Git repository layers/meta-devkit/   # Read-only bind mount inside the container
  └── hello-yocto                 # Custom BitBake recipe and C++ source
```

The Yocto 6.0 setup uses **four upstream Git repositories**, rather than relying on older Poky monorepo instructions: BitBake, OpenEmbedded-Core and `meta-yocto` on `yocto-6.0`, plus `meta-openembedded` on its `wrynose` branch. Existing clones are never silently updated, which preserves a working configuration. Their Git commit IDs can be inspected in each checkout for reproducibility.

The included `meta-devkit` layer is mounted read-only at `/opt/devkit/meta-devkit`. To edit a recipe, edit the files in your source checkout and rebuild. The generated `local.conf` references the cache directories, selects `qemux86-64` and enables the `hello-yocto` example. `meta-oe` is also registered so that embedded Catch2, fmt and spdlog recipes are available.

## Configuration and portability

By default, build output stays outside the Git checkout. To select a different location, set `YOCTO_DEVKIT_WORKSPACE` **before every command**:

```bash
export YOCTO_DEVKIT_WORKSPACE="$HOME/Embedded/yocto-workspace"
./bin/yocto-devkit setup
./bin/yocto-devkit build
```

The first setup generates an explicitly marked configuration block in `build/conf/local.conf`; subsequent runs do not overwrite it. If you alter `MACHINE`, distro settings, or upstream branches, ensure every layer is compatible and treat it as a separate validated configuration. The starter CLI/QEMU workflow is currently designed for `qemux86-64` only.

For a fresh computer, clone this repository and run `setup` again. Download and build caches are specific to the machine unless you deliberately move them. Do not commit the generated workspace into this public repository.

## Security notes

- Docker socket access is **root-equivalent**. The installer never adds your user to the `docker` group. It uses current access or `sudo` as required.
- Builds use the host's numeric UID/GID, a normal non-root user inside Docker, minimal capabilities and `no-new-privileges`.
- Source repositories are cloned over HTTPS. Failed partial clones are retried without deleting valid existing checkouts.
- QEMU runs headlessly with user networking (`slirp`) and does not require host networking or `--privileged`.
- The example image intentionally enables passwordless root login for testing. **Never ship that configuration on a real device.** Remove the development login features, secure users, and review every package/image recipe before deployment.
- Review external Dockerfiles, upstream repositories and fetched Yocto recipes; container isolation is not a security boundary against all malicious builds.

## Documentation

- [C++ libraries and debugging](docs/CPP_DEBUGGING.md)
- [Architecture and design choices](docs/ARCHITECTURE.md)
- [Troubleshooting and recovery](docs/TROUBLESHOOTING.md)
- [Yocto Project 6.0 quick start](https://docs.yoctoproject.org/6.0/brief-yoctoprojectqs/index.html)
- [Manual Poky environment setup](https://docs.yoctoproject.org/6.0/dev-manual/poky-manual-setup.html)
- [QEMU development manual](https://docs.yoctoproject.org/6.0/dev-manual/qemu.html)

## Tests and contributions

```bash
bash tests/test_cli.sh
```

Tests cover Bash syntax, command validation, help text, layer metadata and compilation/execution of the standalone C++ example. GitHub Actions runs them on every push and pull request. A full image build is intentionally not part of CI because it needs substantially more disk, RAM, network traffic and time than a lightweight runner.

Contributions are welcome through pull requests. Please use descriptive commit messages, keep scripts idempotent, avoid destructive cleanup, and document any change in the supported Yocto release.

## License

MIT License. See [LICENSE](LICENSE). Yocto, BitBake, OpenEmbedded and Docker are separate third-party projects with their own licenses and trademarks.