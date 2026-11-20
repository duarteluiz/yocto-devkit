# Troubleshooting and recovery

## Quick diagnostics

```bash
./bin/yocto-devkit doctor
./bin/yocto-devkit logs
```

The installer fails with a non-zero exit status and prints the log location. Setup is safe to retry after transient connection problems.

## Docker is missing or inaccessible

```bash
./bin/yocto-devkit setup --install-docker
sudo systemctl status docker
sudo systemctl start docker
```

The install option uses Ubuntu's `docker.io` package, not a downloaded shell installer. The script does not automatically grant membership in the root-equivalent Docker group. If Docker works only as root, it can use `sudo` (and prompt for credentials when attached to a terminal).

If apt cannot locate `docker.io`, verify that Ubuntu package sources are enabled and consult the official Docker Engine Ubuntu installation guide: https://docs.docker.com/engine/install/ubuntu/

## Downloads fail or Git clone is interrupted

Check DNS, HTTPS access, proxy settings and disk space. The container retries each upstream and mirror clone twice (up to four attempts per repository). You can re-run:

```bash
./bin/yocto-devkit setup
```

The installer will not overwrite a valid existing clone. If a staging clone was interrupted, the next setup safely replaces the generated `.clone-partial` directory. Build-time fetch failures are reported by BitBake itself; `DL_DIR` caches successful downloads between runs.

## BitBake fails because resources are exhausted

Free disk space in the workspace filesystem, and close memory-hungry applications. Check `build/conf/local.conf` for:

```bitbake
BB_NUMBER_THREADS = "2"
PARALLEL_MAKE = "-j 2"
```

Lower these to `1` on a memory-constrained host. These values are created at setup time and intentionally not reset during future setup runs. For resource-intensive images, use a larger development machine.

## BitBake recipe or layer cannot be found

```bash
./bin/yocto-devkit shell
bitbake-layers show-layers
bitbake-layers show-recipes hello-yocto
bitbake -e hello-yocto | grep '^S='
```

The recipe is in the Git checkout and mounted read-only at `/opt/devkit/meta-devkit`. Check the layer path inside `build/conf/bblayers.conf` and that `LAYERSERIES_COMPAT_devkit` matches `wrynose`.

## QEMU is slow or KVM is not available

```bash
ls -l /dev/kvm
id
```

QEMU uses software emulation when the host user cannot read and write `/dev/kvm`. Enabling hardware virtualization in BIOS/UEFI and granting access to the system KVM group may improve performance; group changes require a new login session. KVM is optional and should not be forced with `--privileged`.

## QEMU reports no usable image

Run a successful build first:

```bash
./bin/yocto-devkit build
ls "$HOME/yocto-devkit-workspace/build/tmp/deploy/images/qemux86-64"
./bin/yocto-devkit run
```

If using `YOCTO_DEVKIT_WORKSPACE`, inspect that custom location instead. The default guest image has no SSH server. Use the serial console for the demonstration.

## Login rejected in QEMU

The example config appends `allow-empty-password allow-root-login empty-root-password` for a test root console. Confirm these options remain in `build/conf/local.conf`, then rebuild the image. Do not use this configuration on deployed devices.

## Clean up without losing source code

Do not delete the workspace unless you intend to lose local downloads, build history and compiled artifacts. To clean one package:

```bash
./bin/yocto-devkit bitbake -c cleansstate hello-yocto
```

To recover from a package-specific error, prefer cleaning only that recipe. To save space, inspect the exact paths before manually removing temporary build outputs; there is intentionally no automatic destructive reset command.

## Catch2 or fmt/spdlog recipe is unavailable

Run setup again to fetch `meta-openembedded` and register `meta-oe`:

```bash
./bin/yocto-devkit setup
./bin/yocto-devkit shell
bitbake-layers show-layers
bitbake-layers show-recipes catch2 fmt spdlog devkit-cpp-tests
```

The `meta-openembedded` checkout uses branch `wrynose` and is preserved between setups. Do not mix incompatible branches.

## CMake cannot locate Catch2 or the sample test fails

Re-run setup to rebuild the Docker image with the updated libraries, then:

```bash
./bin/yocto-devkit cpp-test
```

The container uses Ubuntu's signed apt packages. Do not fix this by globally installing random packages through `pip`, `curl | sh`, or unverified PPAs. Read [C++ debugging](CPP_DEBUGGING.md) for optional sanitizers and symbols.
