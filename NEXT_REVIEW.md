# 下一阶段：第 10 次构建后的设备核对

第 10 次正式构建已完成，详情见 reviews/run-10-2026-10-01.md。无需因为旧脚本要求 kmod-nft-fullcone 而重新构建；当前使用 SONiC 集成到 nft_masq 的方案。

## 云端已核对

- 只有 netcore_n60-pro 目标；镜像 metadata 的 supported_devices 为 netcore,n60-pro。
- sysupgrade 的 SHA-256 与 profiles.json、sha256sums、构建日志一致。
- manifest 包含 mt_wifi、WARP、HNAT、OpenClash、PPPoE 和 USB 存储支持。
- 未发现 mt7915e、mt7986-firmware 或 mt7986-wo-firmware 混入 manifest。
- Full Cone 预编译及 fw4 端口范围检查成功；随包提供的 nft_masq.ko 包含 nft-expr-fullcone 标记。
- 第 10 次验证日志包没有完整 .config；config.buildinfo 和 manifest 已用于本次审核。工作流修复只影响之后的归档。

## 继续升级前需要的设备资料

先在当前路由器执行以下只读命令，提供输出：

    ubus call system board
    cat /proc/mtd
    cat /proc/partitions

这些资料用于核对当前 board_name、target、MTD/UBI 布局，以及是否使用过定制分区或 bootloader。固件 metadata 一致不能代替这一步。

完成设备核对后，再安排备份、配置迁移与回滚路径。镜像传到设备后可以执行 sysupgrade -T 的兼容性检查；-T 不写入固件，但通过也不保证实际运行正常。此阶段不执行正式升级，不使用强制参数绕过失败检查。

## 实机运行后才可确认的项目

- fw4 check、实际 nft 规则和日志中是否正常启用 Full Cone。
- 无线、WAN/LAN、PPPoE、USB、OpenClash 是否正常。
- 独立 NAT 行为测试与 MTK HNAT/WARP 加速情况。
- 新内核是 6.6.133，仓库记录的旧设备内核是 6.6.95；不能直接复用旧内核模块。
