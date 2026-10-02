#!/usr/bin/env bash
# Matches the v5 config validation step.
set -euo pipefail
SRC="${1:-immortalwrt}"
cd "$SRC"

set -euo pipefail
required=(
  'CONFIG_TARGET_mediatek=y'
  'CONFIG_TARGET_mediatek_filogic=y'
  'CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro=y'
  'CONFIG_PACKAGE_kmod-mt_wifi=y'
  'CONFIG_PACKAGE_kmod-warp=y'
  'CONFIG_PACKAGE_kmod-mediatek_hnat=y'
  'CONFIG_PACKAGE_luci-app-mtwifi-cfg=y'
  'CONFIG_PACKAGE_luci-app-turboacc-mtk=y'
  'CONFIG_PACKAGE_luci-app-eqos-mtk=y'
  'CONFIG_PACKAGE_kmod-nft-nat=y'
  'CONFIG_PACKAGE_iptables-nft=y'
  'CONFIG_PACKAGE_luci-app-openclash=y'
  'CONFIG_PACKAGE_luci-theme-argon=y'
  'CONFIG_PACKAGE_luci-app-argon-config=y'
)
for s in "${required[@]}"; do
  grep -Fxq "$s" .config && echo "OK   $s" || { echo "FAIL $s"; exit 30; }
done

for s in \
  CONFIG_PACKAGE_kmod-mt7915e=y \
  CONFIG_PACKAGE_kmod-mt7986-firmware=y \
  CONFIG_PACKAGE_mt7986-wo-firmware=y \
  CONFIG_PACKAGE_kmod-ipt-fullconenat=y \
  CONFIG_PACKAGE_iptables-mod-fullconenat=y \
  CONFIG_PACKAGE_ip6tables-mod-fullconenat=y; do
  ! grep -Fxq "$s" .config && echo "OK   not selected: $s" || { echo "FAIL selected: $s"; exit 31; }
done
