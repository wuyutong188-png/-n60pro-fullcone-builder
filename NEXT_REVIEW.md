# 下一阶段：恢复 v5 固件上传，再核对设备

第 13 次编译已成功，但产物校验因 manifest 路径错误而失败，固件未上传。详情见 reviews/run-13-2026-10-02.md。第 10 次的 v4 产物仍只是历史基线，不能替代 v5 审核。

## 接下来要完成的云端步骤

1. 将校验修复应用到所选构建分支，启动新的 workflow_dispatch，mode=build，保持已验证的两个固定源码 SHA。
2. 不直接重跑 #13：旧运行仍引用旧脚本。修改触发文件也只会运行 validate。
3. 等待真实 v5 产物检查通过并上传正常固件包，核对 manifest 中的 MTK/WARP/HNAT、OpenClash、iptables-nft、Argon 和旧版 FULLCONENAT 排除情况。
4. 核对唯一 N60 Pro 镜像、两份 SHA-256 记录、fwtool metadata 和 tar 结构，保留完整 .config 及 feeds.buildinfo。
5. 若只出现 UNVERIFIED 诊断包，先读取失败原因，不将其作为通过审核的固件。

当前第 13 次的 Full Cone 内核/用户态预编译、fw4 范围检查和完整编译均成功，但缺少该次最终镜像及实际 manifest，因此不能宣称这些产物检查已经通过。配置归档修复只影响后续运行。

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
