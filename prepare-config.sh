#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-immortalwrt}"
cd "$SRC"

if [[ -f defconfig/mt7975-ipailna-high-power.config ]]; then
  BASE="defconfig/mt7975-ipailna-high-power.config"
elif [[ -f defconfig/mt7986-ax6000.config ]]; then
  BASE="defconfig/mt7986-ax6000.config"
else
  echo "ERROR: No suitable MT7986 defconfig found."
  exit 2
fi

echo "Using base config: $BASE"
cp -f "$BASE" .config

# Force the exact target/device.
./scripts/config --enable TARGET_mediatek
./scripts/config --enable TARGET_mediatek_filogic
./scripts/config --enable TARGET_mediatek_filogic_DEVICE_netcore_n60-pro

# Required for the user's current MTK/PadavanOnly stack.
./scripts/config --enable PACKAGE_kmod-mt_wifi
./scripts/config --enable PACKAGE_kmod-warp
./scripts/config --enable PACKAGE_kmod-mediatek_hnat
./scripts/config --enable PACKAGE_luci-app-mtwifi-cfg
./scripts/config --enable PACKAGE_luci-app-turboacc-mtk
./scripts/config --enable PACKAGE_luci-app-eqos-mtk
./scripts/config --enable PACKAGE_mtk-smp
./scripts/config --enable PACKAGE_mtkhqos_util

# The missing feature we are specifically adding.
./scripts/config --enable PACKAGE_kmod-nft-fullcone

# Keep important current functionality when available.
./scripts/config --enable PACKAGE_luci-app-openclash
./scripts/config --enable PACKAGE_kmod-pppoe
./scripts/config --enable PACKAGE_ppp-mod-pppoe
./scripts/config --enable PACKAGE_kmod-usb3
./scripts/config --enable PACKAGE_kmod-usb-storage
./scripts/config --enable PACKAGE_kmod-usb-storage-uas

# These are intentionally excluded because the user does not use them and
# they were the source of stale fw4 includes / legacy-rule warnings.
./scripts/config --disable PACKAGE_wrtbwmon
./scripts/config --disable PACKAGE_luci-app-wrtbwmon
./scripts/config --disable PACKAGE_luci-i18n-wrtbwmon-zh-cn
./scripts/config --disable PACKAGE_luci-app-passwall
./scripts/config --disable PACKAGE_luci-i18n-passwall-zh-cn
./scripts/config --disable PACKAGE_zerotier
./scripts/config --disable PACKAGE_luci-app-zerotier
./scripts/config --disable PACKAGE_luci-i18n-zerotier-zh-cn

make defconfig

echo "Prepared .config."
