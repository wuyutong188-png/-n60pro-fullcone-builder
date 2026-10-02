#!/usr/bin/env bash
# Matches the v5 prepare and TurboACC decoupling steps.
set -euo pipefail
SRC="${1:-immortalwrt}"
cd "$SRC"

set -euo pipefail

if [[ -f defconfig/mt7975-ipailna-high-power.config ]]; then
  BASE=defconfig/mt7975-ipailna-high-power.config
elif [[ -f defconfig/mt7986-ax6000.config ]]; then
  BASE=defconfig/mt7986-ax6000.config
else
  echo "ERROR: no suitable MT7986 defconfig found"
  exit 20
fi

cp -f "$BASE" .config
echo "Using base config: $BASE"

set_cfg() {
  local sym="$1" val="$2"
  sed -i -e "/^${sym}=.*/d" -e "/^# ${sym} is not set$/d" .config
  case "$val" in
    y|m) echo "${sym}=${val}" >> .config ;;
    n) echo "# ${sym} is not set" >> .config ;;
    *) echo "invalid config value"; exit 21 ;;
  esac
}

set_cfg CONFIG_TARGET_mediatek y
set_cfg CONFIG_TARGET_mediatek_filogic y
set_cfg CONFIG_TARGET_mediatek_filogic_DEVICE_netcore_n60-pro y

set_cfg CONFIG_PACKAGE_kmod-mt_wifi y
set_cfg CONFIG_PACKAGE_kmod-warp y
set_cfg CONFIG_PACKAGE_kmod-mediatek_hnat y
set_cfg CONFIG_PACKAGE_luci-app-mtwifi-cfg y
set_cfg CONFIG_PACKAGE_luci-app-turboacc-mtk y
set_cfg CONFIG_PACKAGE_luci-app-eqos-mtk y
set_cfg CONFIG_PACKAGE_mtk-smp y
set_cfg CONFIG_PACKAGE_mtkhqos_util y

set_cfg CONFIG_PACKAGE_kmod-nft-nat y
set_cfg CONFIG_PACKAGE_kmod-nft-offload y
set_cfg CONFIG_PACKAGE_iptables-nft y
set_cfg CONFIG_PACKAGE_luci-app-openclash y
set_cfg CONFIG_PACKAGE_luci-theme-argon y
set_cfg CONFIG_PACKAGE_luci-app-argon-config y
set_cfg CONFIG_PACKAGE_kmod-pppoe y
set_cfg CONFIG_PACKAGE_ppp-mod-pppoe y
set_cfg CONFIG_PACKAGE_kmod-usb3 y
set_cfg CONFIG_PACKAGE_kmod-usb-storage y
set_cfg CONFIG_PACKAGE_kmod-usb-storage-uas y

set_cfg CONFIG_PACKAGE_kmod-mt7915e n
set_cfg CONFIG_PACKAGE_kmod-mt7986-firmware n
set_cfg CONFIG_PACKAGE_mt7986-wo-firmware n
set_cfg CONFIG_PACKAGE_kmod-ipt-fullconenat n
set_cfg CONFIG_PACKAGE_iptables-mod-fullconenat n
set_cfg CONFIG_PACKAGE_ip6tables-mod-fullconenat n

set_cfg CONFIG_PACKAGE_wrtbwmon n
set_cfg CONFIG_PACKAGE_luci-app-wrtbwmon n
set_cfg CONFIG_PACKAGE_luci-i18n-wrtbwmon-zh-cn n
set_cfg CONFIG_PACKAGE_luci-app-passwall n
set_cfg CONFIG_PACKAGE_luci-i18n-passwall-zh-cn n
set_cfg CONFIG_PACKAGE_zerotier n
set_cfg CONFIG_PACKAGE_luci-app-zerotier n
set_cfg CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn n

make defconfig

set -euo pipefail
python3 - <<'PY'
from pathlib import Path

def replace_exact(path, old, new):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"Expected text not found in {path}: {old!r}")
    p.write_text(s.replace(old, new, 1))

replace_exact(
    "package/mtk/applications/luci-app-turboacc-mtk/Makefile",
    "\t+kmod-ipt-fullconenat +kmod-fs-btrfs +luci-app-ttyd +kmod-bonding \\\n",
    "\t+kmod-fs-btrfs +luci-app-ttyd +kmod-bonding \\\n",
)

replace_exact(
    "package/mtk/applications/luci-app-turboacc-mtk/root/etc/init.d/turboacc",
    '''\n\tlocal fullcone\n\tconfig_get "fullcone" "config" "fullcone" "2"\n\techo "$fullcone" > /proc/sys/net/netfilter/nf_conntrack_nat_mode\n''',
    "\n",
)

replace_exact(
    "package/mtk/applications/luci-app-turboacc-mtk/root/etc/uci-defaults/turboacc",
    '\nuci -q set "turboacc.config.fullcone"="2"\n',
    "\n",
)

js = Path("package/mtk/applications/luci-app-turboacc-mtk/htdocs/luci-static/resources/view/turboacc.js")
s = js.read_text()
replacements = [
    ("""var getFullConeStat = rpc.declare({\n\tobject: 'luci.turboacc',\n\tmethod: 'getFullConeStat',\n\texpect: { '': {} }\n});\n\n""", ""),
    ("""\t\tL.resolveDefault(getFastPathStat(), {}),\n\t\tL.resolveDefault(getFullConeStat(), {}),\n\t\tL.resolveDefault(getTCPCCAStat(), {})\n""",
     """\t\tL.resolveDefault(getFastPathStat(), {}),\n\t\tL.resolveDefault(getTCPCCAStat(), {})\n"""),
    ("""\t\t\t\tvar tds = [ 'fastpath_state', 'fullcone_state', 'tcpcca_state' ];\n""",
     """\t\t\t\tvar tds = [ 'fastpath_state', 'tcpcca_state' ];\n"""),
    ("""\t\t\t\tE('tr', {}, [\n\t\t\t\t\tE('td', { 'width': '33%' }, _('Full Cone NAT')),\n\t\t\t\t\tE('td', { 'id': 'fullcone_state' }, E('em', {}, _('Collecting data...')))\n\t\t\t\t]),\n""", ""),
    ("""\n\t\to = s.option(form.ListValue, 'fullcone', _('Full cone NAT'),\n\t\t\t_('Full cone NAT (NAT1) can improve gaming performance effectively.'));\n\t\to.value('0', _('Disable'))\n\t\to.value('2', _('Boardcom_FULLCONE_NAT'));\n\t\to.default = '0';\n\t\to.rmempty = false;\n""", "\n"),
]
for old, new in replacements:
    if old not in s:
        raise SystemExit("Expected TurboACC JS block not found")
    s = s.replace(old, new, 1)
js.write_text(s)

rpc = Path("package/mtk/applications/luci-app-turboacc-mtk/root/usr/libexec/rpcd/luci.turboacc")
s = rpc.read_text()
old = '\t\t\t\thasXTFULLCONENAT  = fs.access("/lib/modules/" .. boardinfo.kernel .. "/xt_FULLCONENAT.ko"),\n'
if old not in s:
    raise SystemExit("Expected TurboACC RPC feature line not found")
s = s.replace(old, "", 1)
start = s.find("\tgetFullConeStat = {")
end = s.find("\tgetTCPCCAStat = {", start)
if start < 0 or end < 0:
    raise SystemExit("Expected TurboACC RPC getFullConeStat block not found")
s = s[:start] + s[end:]
rpc.write_text(s)
PY

# Re-resolve config after dropping the legacy dependency.
for sym in \
  CONFIG_PACKAGE_kmod-ipt-fullconenat \
  CONFIG_PACKAGE_iptables-mod-fullconenat \
  CONFIG_PACKAGE_ip6tables-mod-fullconenat; do
  sed -i -e "/^${sym}=.*/d" -e "/^# ${sym} is not set$/d" .config
  echo "# ${sym} is not set" >> .config
done
make defconfig
