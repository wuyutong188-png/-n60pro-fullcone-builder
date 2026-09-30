#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-immortalwrt}"
OUT="$SRC/bin/targets/mediatek/filogic"

[[ -d "$OUT" ]] || { echo "ERROR: target output directory missing"; exit 20; }

echo "===== OUTPUT FILES ====="
find "$OUT" -maxdepth 1 -type f -printf '%f\n' | sort

MANIFEST="$(find "$OUT" -maxdepth 1 -type f -name '*manifest*' | head -n1 || true)"
[[ -n "$MANIFEST" ]] || { echo "ERROR: manifest not found"; exit 21; }

echo
echo "===== MANIFEST CHECK ====="
required_pkgs=(
  kmod-nft-fullcone
  kmod-mt_wifi
  kmod-warp
  kmod-mediatek_hnat
)
for p in "${required_pkgs[@]}"; do
  if grep -Eq "^${p}[[:space:]-]" "$MANIFEST"; then
    echo "OK   $p"
  else
    echo "FAIL $p missing from firmware manifest"
    exit 22
  fi
done

for p in kmod-mt7915e kmod-mt7986-firmware mt7986-wo-firmware; do
  if grep -Eq "^${p}[[:space:]-]" "$MANIFEST"; then
    echo "FAIL forbidden package present: $p"
    exit 23
  fi
done

IMAGE="$(find "$OUT" -maxdepth 1 -type f \( -iname '*netcore*n60*pro*sysupgrade*' -o -iname '*n60-pro*sysupgrade*' \) | head -n1 || true)"
[[ -n "$IMAGE" ]] || { echo "ERROR: N60 Pro sysupgrade image not found"; exit 24; }

echo
echo "===== IMAGE ====="
ls -lh "$IMAGE"
sha256sum "$IMAGE"

echo
echo "Build artifact passed manifest checks."
echo "IMPORTANT: this does not mean it is automatically safe to flash."
echo "Compare metadata and package manifest with the current router before flashing."
