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

set_cfg() {
  local sym="$1"
  local val="$2"

  sed -i \
    -e "/^${sym}=.*/d" \
    -e "/^# ${sym} is not set$/d" \
    .config

  case "$val" in
    y|m)
      echo "${sym}=${val}" >> .config
      ;;
    n)
      echo "# ${sym} is not set" >> .config
      ;;
    *)
      echo "ERROR: unsupported value '$val' for $sym"
      exit 3
      ;;
  esac
}

# Lock target/device.
set_cfg CONFIG_TARGET_mediatek y
set_cfg CONFIG_TARGET_mediatek_filogic y
set_cfg CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro y

# Preserve the current MTK/PadavanOnly acceleration & Wi-Fi stack.
set_cfg CONFIG_PACKAGE_kmod-mt_wifi y
set_cfg CONFIG_PACKAGE_kmod-warp y
set_cfg CONFIG_PACKAGE_kmod-mediatek_hnat y
set_cfg CONFIG_PACKAGE_luci-app-mtwifi-cfg y
set_cfg CONFIG_PACKAGE_luci-app-turboacc-mtk y
set_cfg CONFIG_PACKAGE_luci-app-eqos-mtk y
set_cfg CONFIG_PACKAGE_mtk-smp y
set_cfg CONFIG_PACKAGE_mtkhqos_util y

# Add the missing Full Cone module.
set_cfg CONFIG_PACKAGE_kmod-nft-fullcone y

# Preserve important current functions where available.
set_cfg CONFIG_PACKAGE_luci-app-openclash y
set_cfg CONFIG_PACKAGE_kmod-pppoe y
set_cfg CONFIG_PACKAGE_ppp-mod-pppoe y
set_cfg CONFIG_PACKAGE_kmod-usb3 y
set_cfg CONFIG_PACKAGE_kmod-usb-storage y
set_cfg CONFIG_PACKAGE_kmod-usb-storage-uas y

# Intentionally omit unused/problematic packages.
set_cfg CONFIG_PACKAGE_wrtbwmon n
set_cfg CONFIG_PACKAGE_luci-app-wrtbwmon n
set_cfg CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn n
set_cfg CONFIG_PACKAGE_luci-app-passwall n
set_cfg CONFIG_PACKAGE_luci-i18n-passwall-zh-cn n
set_cfg CONFIG_PACKAGE_zerotier n
set_cfg CONFIG_PACKAGE_luci-app-zerotier n
set_cfg CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn n

make defconfig

echo "Prepared .config."
