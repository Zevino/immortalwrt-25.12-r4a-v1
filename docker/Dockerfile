# Optional containerized build environment.
#
# Build:
#   docker build -t immortalwrt-builder:25.12 docker/
#
# Run (from the project root, on Linux/WSL2):
#   docker run --rm -it -v "$PWD:/work" -w /work \
#     immortalwrt-builder:25.12 bash scripts/build.sh all
#
# Keep the source tree on a Linux filesystem (WSL2 ext4 or a Docker volume).
# Building directly on /mnt/c is slow and can fail because of case sensitivity.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
      gettext git libncurses-dev libssl-dev libelf-dev \
      python3 python3-pip python3-setuptools python3-ply python3-pyelftools \
      rsync unzip zlib1g-dev file wget curl ca-certificates \
      device-tree-compiler swig time xsltproc zip cmake patch bc \
      libxml-parser-perl libtool-bin autoconf automake pkg-config gperf \
      bzip2 cpio zstd lz4 ccache nano vim xxd \
      diffutils findutils sed tar gzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${GID}" builder 2>/dev/null || true \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash builder 2>/dev/null || true \
    && mkdir -p /build \
    && chown -R "${UID}:${GID}" /build

USER ${UID}:${GID}
WORKDIR /build

CMD ["/bin/bash"]
