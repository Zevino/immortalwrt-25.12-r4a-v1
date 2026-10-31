#!/usr/bin/env bash
#
# Build ImmortalWrt 25.12 for Xiaomi Mi Router 4A Gigabit Edition (V1)
#
# Usage:
#   ./scripts/build.sh              # full build (prepare + download + build + collect)
#   ./scripts/build.sh prepare      # clone source, update feeds, generate .config
#   ./scripts/build.sh menuconfig   # interactive package selection
#   ./scripts/build.sh download     # pre-download source tarballs
#   ./scripts/build.sh build        # compile
#   ./scripts/build.sh collect      # copy artifacts to out/
#   ./scripts/build.sh clean        # make clean (keeps .config and source)
#   ./scripts/build.sh distclean    # make distclean (removes build dirs and .config)
#
# Environment:
#   BRANCH=openwrt-25.12
#   SOURCE_COMMIT=<sha>             # optional: pin a commit
#   SOURCE_DIR=...                  # default: <project>/source
#   OUT_DIR=...                     # default: <project>/out
#   CONFIG_FILE=...                 # default: <project>/configs/r4a-v1.config
#   EXTRA_PACKAGES="pkg1 pkg2"      # appended as CONFIG_PACKAGE_<pkg>=y
#   JOBS=<n>                        # default: nproc

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${BRANCH:-openwrt-25.12}"
SOURCE_DIR="${SOURCE_DIR:-$PROJECT_DIR/source}"
OUT_DIR="${OUT_DIR:-$PROJECT_DIR/out}"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/configs/r4a-v1.config}"
REPO_URL="${REPO_URL:-https://github.com/immortalwrt/immortalwrt.git}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
STAGE="${1:-all}"

DEVICE="xiaomi_mi-router-4a-gigabit"
TARGET_SUBDIR="ramips/mt7621"

log()  { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*" >&2; }
die()  { printf '\n\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

need_linux() {
  [ "$(uname -s)" = "Linux" ] || die "请在 Linux / WSL2 中运行（macOS 和 Windows 原生不支持）"
  [ "$(id -u)" -ne 0 ] || die "不要用 root 构建；请用普通用户运行"
}

check_host() {
  command -v git  >/dev/null || die "缺少 git，请先运行 ./scripts/install-deps.sh"
  command -v make >/dev/null || die "缺少 make，请先运行 ./scripts/install-deps.sh"
  command -v gcc  >/dev/null || die "缺少 gcc，请先运行 ./scripts/install-deps.sh"

  local avail_kb
  avail_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
  if [ "${avail_kb:-0}" -lt 26214400 ]; then
    warn "项目所在分区可用空间不足 25 GB，编译可能中途失败（当前约 $((avail_kb / 1024 / 1024)) GB）"
  fi

  local mem_kb
  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
  if [ "${mem_kb:-0}" -lt 3800000 ]; then
    warn "内存不足 4 GB，建议增加内存或调低 JOBS"
  fi

  [ -f "$CONFIG_FILE" ] || die "找不到配置文件：$CONFIG_FILE"
}

prepare() {
  log "准备源码：$BRANCH"

  if [ ! -d "$SOURCE_DIR/.git" ]; then
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --branch "$BRANCH" --single-branch --filter=blob:none \
      "$REPO_URL" "$SOURCE_DIR"
  else
    log "复用已有源码：$SOURCE_DIR"
    git -C "$SOURCE_DIR" rev-parse --short HEAD
    warn "如需更新源码，请手动执行：git -C \"$SOURCE_DIR\" pull --ff-only"
  fi

  if [ -n "${SOURCE_COMMIT:-}" ]; then
    log "切换到固定提交：$SOURCE_COMMIT"
    git -C "$SOURCE_DIR" fetch origin "$SOURCE_COMMIT" --depth 1
    git -C "$SOURCE_DIR" checkout --detach "$SOURCE_COMMIT"
  fi

  # Guard: device definition must exist in this branch.
  local image_mk="$SOURCE_DIR/target/linux/ramips/image/mt7621.mk"
  grep -q "^define Device/${DEVICE}$" "$image_mk" \
    || die "当前源码里找不到设备 $DEVICE，请确认分支或设备标识"

  log "更新 feeds"
  (
    cd "$SOURCE_DIR"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
  )

  log "写入配置：$CONFIG_FILE"
  cp -f "$CONFIG_FILE" "$SOURCE_DIR/.config"

  if [ -n "${EXTRA_PACKAGES:-}" ]; then
    log "追加软件包：$EXTRA_PACKAGES"
    for pkg in $EXTRA_PACKAGES; do
      case "$pkg" in
        *[!A-Za-z0-9._+-]*)
          die "非法包名：$pkg"
          ;;
      esac
      printf 'CONFIG_PACKAGE_%s=y\n' "$pkg" >> "$SOURCE_DIR/.config"
    done
  fi

  log "展开默认配置（make defconfig）"
  (
    cd "$SOURCE_DIR"
    make defconfig
  )

  mkdir -p "$OUT_DIR"
  (
    cd "$SOURCE_DIR"
    ./scripts/diffconfig.sh > "$OUT_DIR/config.applied" || true
  )
  log "已保存非默认配置：$OUT_DIR/config.applied"
}

menuconfig() {
  prepare
  log "进入 menuconfig；保存后建议重新导出 configs/"
  ( cd "$SOURCE_DIR" && make menuconfig )
  (
    cd "$SOURCE_DIR"
    ./scripts/diffconfig.sh > "$PROJECT_DIR/configs/r4a-v1.applied.config" || true
  )
  log "已导出：configs/r4a-v1.applied.config"
}

download() {
  [ -f "$SOURCE_DIR/.config" ] || prepare
  log "预下载源码包（失败会自动重试单线程）"
  (
    cd "$SOURCE_DIR"
    make download -j"$JOBS" || make download -j1 V=s
  )
}

build() {
  [ -f "$SOURCE_DIR/.config" ] || prepare
  log "开始编译：-j$JOBS（首次约 2–4 小时）"
  if ! ( cd "$SOURCE_DIR" && make -j"$JOBS" ); then
    warn "并行编译失败。用单线程 + 详细日志复现："
    warn "  cd \"$SOURCE_DIR\" && make -j1 V=s"
    exit 1
  fi
}

collect() {
  log "收集产物"
  SOURCE_DIR="$SOURCE_DIR" OUT_DIR="$OUT_DIR" bash "$PROJECT_DIR/scripts/collect.sh"
}

clean() {
  [ -d "$SOURCE_DIR" ] || die "源码目录不存在：$SOURCE_DIR"
  ( cd "$SOURCE_DIR" && make clean )
}

distclean() {
  [ -d "$SOURCE_DIR" ] || die "源码目录不存在：$SOURCE_DIR"
  ( cd "$SOURCE_DIR" && make distclean )
}

need_linux
check_host

case "$STAGE" in
  all)
    prepare
    download
    build
    collect
    ;;
  prepare|menuconfig|download|build|collect|clean|distclean)
    "$STAGE"
    ;;
  *)
    die "未知阶段：$STAGE（可用：all prepare menuconfig download build collect clean distclean）"
    ;;
esac

log "完成"
