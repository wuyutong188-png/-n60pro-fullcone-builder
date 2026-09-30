#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-immortalwrt}"
cd "$SRC"

required=(
  'CONFIG_TARGET_mediatek=y'
  'CONFIG_TARGET_mediatek_filogic=y'
  'CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro=y'
  'CONFIG_PACKAGE_kmod-nft-fullcone=y'
  'CONFIG_PACKAGE_kmod-mt_wifi=y'
  'CONFIG_PACKAGE_kmod-warp=y'
  'CONFIG_PACKAGE_kmod-mediatek_hnat=y'
)

optional=(
  'CONFIG_PACKAGE_luci-app-mtwifi-cfg=y'
  'CONFIG_PACKAGE_luci-app-turboacc-mtk=y'
  'CONFIG_PACKAGE_luci-app-eqos-mtk=y'
  'CONFIG_PACKAGE_luci-app-openclash=y'
)

forbidden=(
  'CONFIG_PACKAGE_kmod-mt7915e=y'
  'CONFIG_PACKAGE_kmod-mt7986-firmware=y'
  'CONFIG_PACKAGE_mt7986-wo-firmware=y'
)

echo "===== REQUIRED CONFIG ====="
for s in "${required[@]}"; do
  if grep -Fxq "$s" .config; then
    echo "OK   $s"
  else
    echo "FAIL $s"
    echo
    echo "The source/config cannot yet reproduce the required N60 Pro MTK stack."
    echo "Do NOT build/flash until this is resolved."
    exit 10
  fi
done

echo
echo "===== FORBIDDEN OPEN-SOURCE WIFI STACK ====="
for s in "${forbidden[@]}"; do
  if grep -Fxq "$s" .config; then
    echo "FAIL selected: $s"
    echo "This builder is intentionally refusing a mixed mt_wifi + mt7915e image."
    exit 11
  else
    echo "OK   not selected: $s"
  fi
done

echo
echo "===== OPTIONAL CURRENT FEATURES ====="
for s in "${optional[@]}"; do
  if grep -Fxq "$s" .config; then
    echo "OK   $s"
  else
    echo "WARN not selected: $s"
  fi
done

echo
echo "Config validation passed."
