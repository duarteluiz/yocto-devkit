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

The host needs only Docker (and Git to clone this repository). All Yocto/C++ build-host dependencies are installed in the container. Setup checks available disk, RAM, CPU, Ubuntu version, Docker daemon access, and KVM support. Low-memory systems receive automatically reduced build parallelism.

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
| `./bin/yocto-devkit build` | Build `core-image-minimal` |
| `./bin/yocto-devkit build core-image-base` | Build a named image |
| `./bin/yocto-devkit run` | Start QEMU with `snapshot nographic slirp` and optional KVM |
| `./bin/yocto-devkit shell` | Open a shell with the Yocto environment initialized |
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

## Architecture

```text
Ubuntu 24.04 host
  ├── ./bin/yocto-devkit         # Setup, diagnostics, build, run and shell
  ├── Docker Engine              # Isolated Ubuntu 24.04 build-host dependencies
  └── ~/yocto-devkit-workspace/  # Persistent data, OUTSIDE the Git checkout
      ├── sources/layers/
      │   ├── bitbake/
      │   ├── openembedded-core/
      │   └── meta-yocto/
      ├── build/                 # conf/, tmp/, logs/, generated images
      ├── cache/
      │   ├── downloads/         # Download cache reused between builds
      │   └── sstate/            # Shared-state cache
      ├── home/                  # Writable container HOME
      └── logs/                  # Timestamped setup logs

Git repository layers/meta-devkit/   # Read-only bind mount inside the container
  └── hello-yocto                 # Custom BitBake recipe and C++ source
```

The Yocto 6.0 setup uses **three separate upstream Git repositories**, rather than relying on older Poky monorepo instructions: BitBake, OpenEmbedded-Core and `meta-yocto`, each on the `yocto-6.0` maintenance branch. Existing clones are never silently updated, which preserves a working configuration. Their Git commit IDs can be inspected in each checkout for reproducibility.

The included `meta-devkit` layer is mounted read-only at `/opt/devkit/meta-devkit`. To edit a recipe, edit the files in your source checkout and rebuild. The generated `local.conf` references the cache directories, selects `qemux86-64` and enables the `hello-yocto` example.

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
