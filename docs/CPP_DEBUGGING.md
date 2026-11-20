# C++ dependencies, debugging and security

## Package provenance

All native C++ libraries and debugging tools are installed by `apt` from the configured, signature-verified Ubuntu 24.04 repositories. No ad-hoc binary download, unverified PPA, global `pip` install, or `curl | sh` is used. Ubuntu package availability and security maintenance depend on your configured repository components and update policy; not all packages have the same Ubuntu security-support level.

The target packages come from official OpenEmbedded recipes on the Yocto 6.0 (`wrynose`) branches. In particular, `catch2`, `fmt` and `spdlog` are provided by `meta-openembedded/meta-oe`. These **are different builds** from the native Ubuntu packages; never copy host `.so` binaries into a cross-compiled target image.

## Useful tools inside Docker

```bash
./bin/yocto-devkit shell

gdb --version
clang++ --version
clang-tidy --version
cppcheck --version
valgrind --version
```

The native test command compiles a Catch2 3.x executable with fmt and spdlog and runs CTest:

```bash
./bin/yocto-devkit cpp-test
```

Build products are stored under `~/yocto-devkit-workspace/cpp-build/` (or your custom workspace); generated binaries, logs and caches are not committed to Git.

## Debug symbols and backtraces

The CMake test is built in `Debug` mode and will contain debug symbols. Start GDB in the container:

```bash
./bin/yocto-devkit shell
gdb /workspace/cpp-build/devkit-cpp-tests
```

In GDB, use `run`, `bt`, `frame`, `info locals`, and `quit`. From the shell, check ELF and symbol data with `file`, `readelf -S`, and `nm -C`.

## Catch memory bugs using Valgrind

```bash
./bin/yocto-devkit shell
valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
    /workspace/cpp-build/devkit-cpp-tests
```

Valgrind runs on the Ubuntu host architecture inside Docker; use target-compatible tooling for programs on a different architecture. Linux kernel and certain allocation patterns can produce environment-specific reports; investigate rather than suppress failures blindly.

## AddressSanitizer and UndefinedBehaviorSanitizer

Sanitizers work best with native development builds rather than silently enabling them for an embedded production image:

```bash
./bin/yocto-devkit shell
cmake -S /opt/devkit/meta-devkit/recipes-test/devkit-cpp-tests/files \
  -B /workspace/cpp-sanitize -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS='-fsanitize=address,undefined -fno-omit-frame-pointer' \
  -DCMAKE_EXE_LINKER_FLAGS='-fsanitize=address,undefined'
cmake --build /workspace/cpp-sanitize
ctest --test-dir /workspace/cpp-sanitize --output-on-failure
```

If a sanitizer runtime cannot run under your container/security configuration, the command fails visibly. Do not disable Docker hardening or use privileged containers just to force a sanitizer test.

## Optional Yocto guest debug profile

By default, only `hello-yocto` is added to `core-image-minimal`; the debug profile is **disabled**.

```bash
./bin/yocto-devkit debug status
./bin/yocto-devkit debug enable
./bin/yocto-devkit build
./bin/yocto-devkit run
```

The opt-in debug block in `build/conf/local.conf` adds:

```bitbake
EXTRA_IMAGE_FEATURES:append = " tools-debug dbg-pkgs dev-pkgs"
IMAGE_INSTALL:append = " devkit-cpp-tests"
```

- `tools-debug`: installs target debugging tools such as GDB and strace.
- `dbg-pkgs`: installs split DWARF/debug symbol packages for software in the image.
- `dev-pkgs`: installs matching development headers and libraries.
- `devkit-cpp-tests`: installs the standalone Catch2 test executable linked against fmt/spdlog. In QEMU, run `devkit-cpp-tests`.

These features significantly increase image size. The image must be rebuilt after changing the profile. For production images, disable the profile and remove the existing development-only passwordless-root options from `local.conf` as well; review SSH, network services, users, package licenses and all debug interfaces before deployment.

## Secure dependency maintenance

- Prefer signed Ubuntu repository updates, and rebuild Docker after dependency updates (`./bin/yocto-devkit setup`).
- Run `./bin/yocto-devkit doctor` to inspect the environment.
- Pin and review all four upstream Git commit SHAs, the DevKit commit and the base container image digest for a strict reproducible release.
- Consider an SBOM (`create-spdx`/SPDX tooling) and regularly review security advisories before commercial deployment.
- The Docker socket is root-equivalent; access to it must be protected. Never expose it to untrusted code.
