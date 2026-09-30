# 下一阶段审核清单

当 validate 通过后，仍需做以下审核，再允许 build/刷机：

1. 保存 Actions 里的完整 `.config`。
2. 确认 N60 Pro target 唯一或至少目标镜像明确。
3. 确认 `CONFIG_PACKAGE_kmod-nft-fullcone=y`。
4. 确认 `kmod-mt_wifi / kmod-warp / kmod-mediatek_hnat` 都为 y。
5. 确认没有 `kmod-mt7915e / kmod-mt7986-firmware / mt7986-wo-firmware`。
6. build 后检查 manifest 和 sysupgrade 文件名。
7. 将新固件 metadata 与当前设备 `ubus call system board`、UBI 布局、target 比较。
8. 在明确回滚/救砖路径之前，不刷写 BL2、FIP、Factory 或 bootloader 镜像。
9. 第一版升级不要假定“保留配置”一定安全；先单独评估配置迁移。
