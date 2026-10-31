#!/usr/bin/env bash
#
# Install build dependencies on Debian/Ubuntu (including WSL2).
# Based on the official ImmortalWrt build requirements.
#
# Usage: ./scripts/install-deps.sh

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "请不要用 root 运行本脚本；脚本内部会调用 sudo。" >&2
  exit 1
fi

command -v sudo >/dev/null || { echo "缺少 sudo" >&2; exit 1; }

echo "==> apt update"
sudo apt-get update

CORE=(
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib
  gettext git libncurses-dev libssl-dev libelf-dev
  python3 python3-pip python3-setuptools python3-ply python3-pyelftools
  rsync unzip zlib1g-dev file wget curl ca-certificates
  device-tree-compiler swig time xsltproc zip cmake patch bc
  libxml-parser-perl libtool-bin autoconf automake pkg-config gperf
  bzip2 cpio zstd lz4 ccache nano vim xxd
)

OPTIONAL=(
  ack antlr3 asciidoc autopoint binutils ecj fastjar gnutls-dev haveged
  help2man intltool lib32gcc-s1 libc6-dev-i386 libglib2.0-dev libgmp3-dev
  libltdl-dev libmpc-dev libmpfr-dev libreadline-dev libyaml-dev
  libpython3-dev lld llvm lrzsz mkisofs msmtp ninja-build p7zip p7zip-full
  python3-docutils qemu-utils re2c scons squashfs-tools subversion texinfo
  uglifyjs upx-ucl xmlto
)

echo "==> 安装核心依赖"
sudo apt-get install -y "${CORE[@]}"

echo "==> 安装可选依赖（个别包在部分发行版不存在，会跳过）"
if ! sudo apt-get install -y "${OPTIONAL[@]}"; then
  echo "==> 整组安装失败，改为逐个安装并跳过缺失项"
  for pkg in "${OPTIONAL[@]}"; do
    sudo apt-get install -y "$pkg" || echo "[skip] $pkg 不可用"
  done
fi

echo
echo "依赖安装完成。下一步："
echo "  ./scripts/build.sh prepare"
