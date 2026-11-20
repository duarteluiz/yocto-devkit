# Ubuntu 24.04 is an officially supported Yocto 6.0 build host.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash build-essential ca-certificates chrpath cpio debianutils diffstat \
    file gawk gcc git iputils-ping libacl1 libcrypt-dev locales \
    python3 python3-git python3-jinja2 python3-pexpect python3-pip \
    python3-subunit python3-websockets socat texinfo unzip wget \
    xz-utils zstd lz4 curl openssh-client cmake ninja-build pkg-config \
    catch2 libfmt-dev libspdlog-dev libboost-dev nlohmann-json3-dev \
    libssl-dev zlib1g-dev libsqlite3-dev \
    gdb gdbserver binutils elfutils valgrind strace ltrace \
    clang clangd clang-format clang-tidy cppcheck ccache lcov \
    && sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# A numeric UID/GID avoids root-owned build outputs on bind-mounted workspaces.
# Ubuntu 24.04 images may already contain UID 1000: reuse it if present.
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN set -eu; \
    if ! getent group "$HOST_GID" >/dev/null; then groupadd --gid "$HOST_GID" devkit; fi; \
    if ! getent passwd "$HOST_UID" >/dev/null; then \
      useradd --uid "$HOST_UID" --gid "$HOST_GID" --create-home --shell /bin/bash devkit; \
    fi; \
    mkdir -p /opt/devkit

COPY scripts/container-init.sh /opt/devkit/container-init.sh
RUN chmod 0755 /opt/devkit/container-init.sh

WORKDIR /workspace
CMD ["bash", "/opt/devkit/container-init.sh", "help"]
