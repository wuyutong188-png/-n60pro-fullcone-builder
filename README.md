# Netcore N60 Pro / PadavanOnly SONiC Full Cone

保留 N60 Pro 的 MTK 无线及加速栈（mt_wifi、WARP、MediaTek HNAT），在此基础上集成 SONiC Full Cone，并适配 PadavanOnly 的 firewall4。

当前方案把 nftables Full Cone expression 集成进现有 nft_masq.ko，由 kmod-nft-nat 提供。**不要求单独的 kmod-nft-fullcone 包**；旧版方案的检查条件已不适用。

## 最近已完成的构建

- [验证 #9](https://github.com/wuyutong188-png/-n60pro-fullcone-builder/actions/runs/36832580097)：成功。
- [正式构建 #10](https://github.com/wuyutong188-png/-n60pro-fullcone-builder/actions/runs/36844763347)：2026-10-01 20:36（北京时间）完成。
- 固件包：netcore-n60-pro-fullcone-v4-10；验证日志包：n60pro-fullcone-v4-10。
- [第 10 次构建审核记录](reviews/run-10-2026-10-01.md)。
- 构建成功和产物静态检查通过不等于路由器实机验证完成。升级前仍按 [NEXT_REVIEW.md](NEXT_REVIEW.md) 核对。

## 固定源码

| 来源 | 提交 |
| --- | --- |
| PadavanOnly | ec9ef10efc65da1e6d1de4e2c043c0e13d08eed8 |
| SONiC Full Cone | 4de0643f6b48e7e7d57d768144204ce5d3078c8f |

feeds 使用源码中的配置更新；每次构建的实际 feed 提交保存在 feeds.buildinfo 中。仅固定以上两个仓库，不能保证未来构建的所有依赖完全相同。

## 使用方式

在 Actions 中选择 N60 Pro SONiC Full Cone v4，手动运行 workflow_dispatch。默认 mode=validate；只有验证结果经过审核后，才以同样的固定源码运行 mode=build。修改 .github/n60pro-trigger.txt 仅启动 validate。

工作流包含：

1. 检查 N60 Pro 配置，保持 MTK/WARP/HNAT、OpenClash、PPPoE 和 USB 功能。
2. 编译内核、iptables、libnftnl、nftables 和 firewall4；核对 Full Cone 端口范围兼容补丁。
3. 保存完整 .config 及验证日志。
4. build 模式生成固件，校验机型、实际 package manifest、SHA-256、fwtool metadata 和 sysupgrade tar 内容后上传。

固件升级镜像为 immortalwrt-mediatek-filogic-netcore_n60-pro-squashfs-sysupgrade.bin。产物中的 initramfs、BL2 等文件不是此处的常规系统升级入口。

## 本地检查

根目录和 scripts/ 下的同名 shell 入口均调用同一份辅助实现。配置辅助脚本与 v4 工作流一致；它们本身不负责应用 SONiC 补丁。

在已经构建的源码目录上运行：

    bash scripts/verify-image.sh /path/to/immortalwrt

检查已解压的产物：

    python3 scripts/verify-firmware.py --output-dir /path/to/artifact --fwtool /path/to/host/fwtool

需要 Python 3.11+ 和宿主机 fwtool。检查只读取固件及其旁边的 manifest、profiles.json、config.buildinfo、sha256sums，不写入路由器。

## 审核范围

静态检查验证产物一致性及软件包选择。Full Cone 的实机加载、NAT 行为、硬件加速效果，以及现有设备的分区和配置迁移仍需单独验证。
