#!/usr/bin/env bash
#
# Copy build artifacts from bin/targets/ramips/mt7621 to out/.
#
# Environment:
#   SOURCE_DIR  default: <project>/source
#   OUT_DIR     default: <project>/out

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-$PROJECT_DIR/source}"
OUT_DIR="${OUT_DIR:-$PROJECT_DIR/out}"
TARGET_DIR="$SOURCE_DIR/bin/targets/ramips/mt7621"

[ -d "$TARGET_DIR" ] || {
  echo "[error] 构建产物目录不存在：$TARGET_DIR" >&2
  echo "        请先完成 ./scripts/build.sh build" >&2
  exit 1
}

mkdir -p "$OUT_DIR"

# Copy regular files at the top level (images, sha256sums, manifest, buildinfo).
find "$TARGET_DIR" -maxdepth 1 -type f -exec cp -f {} "$OUT_DIR"/ \;

# Keep a copy of the effective non-default config if available.
if [ -f "$SOURCE_DIR/.config" ]; then
  ( cd "$SOURCE_DIR" && ./scripts/diffconfig.sh > "$OUT_DIR/config.applied" 2>/dev/null || true )
fi

echo "==> 产物已复制到 $OUT_DIR"
ls -lh "$OUT_DIR"

SYSUPGRADE="$(find "$OUT_DIR" -maxdepth 1 -type f -name "*xiaomi_mi-router-4a-gigabit*sysupgrade.bin" | head -n1 || true)"
if [ -n "$SYSUPGRADE" ]; then
  echo
  echo "刷机文件：$SYSUPGRADE"
  if command -v sha256sum >/dev/null; then
    echo "SHA256：$(sha256sum "$SYSUPGRADE" | awk '{print $1}')"
  fi
else
  echo
  echo "[warn] 没找到 sysupgrade.bin，请检查构建日志或设备标识。" >&2
fi
