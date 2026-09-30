# Netcore N60 Pro / PadavanOnly Full Cone 云编译骨架

这个仓库模板的目标不是“换一套固件体系”，而是尽量保持当前路由器的 MTK/PadavanOnly 驱动栈，并补上缺失的 `kmod-nft-fullcone`。

## 已知当前路由器基线

- 设备：Netcore N60 Pro
- 当前系统：ImmortalWrt 24.10-SNAPSHOT r33412-87f9199b1d
- 当前内核：6.6.95
- 当前核心 MTK 栈：
  - `kmod-mt_wifi`
  - `kmod-warp`
  - `kmod-mediatek_hnat`
  - `luci-app-mtwifi-cfg`
  - `luci-app-turboacc-mtk`
  - `luci-app-eqos-mtk`
- 当前 Full Cone 配置已开启，但因为缺少内核 Full Cone expression，`fw4 check` 会自动关闭 Full Cone。

## 为什么这个工作流默认只做 validate

PadavanOnly 当前公开源码会变化，而且 N60 Pro 的公开设备定义可能默认使用开源 `mt7915e` 驱动。当前路由器实际使用的是 `mt_wifi + WARP + HNAT`。

因此第一次运行必须选择：

`mode = validate`

验证阶段会：

1. 克隆 PadavanOnly `openwrt-24.10-6.6`；
2. 优先采用 `defconfig/mt7975-ipailna-high-power.config`，不存在时才退回 `mt7986-ax6000.config`；
3. 锁定 `netcore_n60-pro`；
4. 尝试启用 `kmod-nft-fullcone`；
5. 尝试保持 `mt_wifi / WARP / HNAT`；
6. 如果发现最终 `.config` 混入 `kmod-mt7915e` 开源无线栈，立即失败，不生成“可刷”固件。

只有 validate 通过后，才应再次手动运行并选择：

`mode = build`

## GitHub 上怎么用

1. 新建一个空白仓库，例如 `n60pro-fullcone-builder`。
2. 把本压缩包中的全部文件上传到仓库根目录，必须保留：
   `.github/workflows/build-n60pro.yml`
3. 打开仓库的 **Actions**。
4. 选择 **Build N60 Pro PadavanOnly Full Cone**。
5. 点 **Run workflow**。
6. 第一次保持 `mode=validate`。
7. 把 Actions 日志中的 `Validate source/config` 结果发回 ChatGPT 审核。

## 非常重要

- 第一轮产物即使编译成功，也不要直接刷。
- `verify-image.sh` 会检查 manifest 是否同时具备 `kmod-nft-fullcone + mt_wifi + WARP + HNAT`，并拒绝混入 `mt7915e`。
- 这只能降低风险，不能替代刷机前的 sysupgrade metadata、UBI/设备兼容性和配置迁移检查。
- 不要为了通过检查而删除验证脚本。
