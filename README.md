# TWRP xpeng GitHub Actions

GitHub Actions 仓库：为 Motorola **xpeng**（XT2175-1 G200 5G / XT2175-2 Edge S30）编译 TWRP `boot.img`（recovery-as-boot）。

设备树：[LuoJuly/twrp_android_device_motorola_xpeng](https://github.com/LuoJuly/twrp_android_device_motorola_xpeng)

## Workflows

在仓库 **Actions** 页手动运行（`workflow_dispatch`）。仅仓库 owner 可触发。

| Workflow | 设备树分支 | Manifest | Lunch | JDK | 界面版本 / 产物 | GitHub Latest |
|---|---|---|---|---|---|---|
| **Build TWRP 12.1 (xpeng)** | `android-12.1` | [minimal-manifest-twrp](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp) `twrp-12.1` | `twrp_xpeng-eng` | 11 | `3.7.1_12-0_stock_by LuoJuly` / `boot_twrp_xpeng_stock_3.7.1_a12.1.img` | 否 |
| **Build TWRP 16.0 (xpeng)** | `android-16.0` | [TWRP-Test](https://github.com/TWRP-Test/platform_manifest_twrp_aosp) `twrp-16.0` | `twrp_xpeng-bp2a-eng` | 17 | `3.7.1_16-0_lineage_by LuoJuly` / `boot_twrp_xpeng_lineage_3.7.1_a16.0.img` | 是 |

可选输入：

- `device_tree_ref` — 覆盖设备树分支（默认见上表）
- `lunch_combo` — 覆盖 lunch
- `publish_release` — 是否发 Release（默认开）
- `runner` — 12.1 默认 `ubuntu-24.04`；**16.0 默认 `self-hosted`**（托管机编 A16 会 OOM 失联）

Release tag 形如 `v3.7.1_12-0-YYYYMMDD` / `v3.7.1_16-0-YYYYMMDD`；同日重复构建会追加 `-r<run_number>`。

12.1 的 Release **不会**抢 16.0 的 Latest。

## 编译时会做什么

1. `repo init --depth=1` + `repo sync`
2. clone 设备树到 `device/motorola/xpeng`
3. 若存在 `twrp.dependencies`，转成 roomservice 再 sync（16.0 会拉 `device/qcom/twrp-common` 和 `device/qcom/common`）
4. 应用设备树 `patches/`（**不含** `patches/disabled/`）：
   - `patches/*.patch` → `bootable/recovery`
   - `patches/gpt-utils/*.patch` → `device/qcom/common`（backup GPT）
   - `patches/vibrator/*.patch` → `vendor/qcom/opensource/vibrator`
   - `patches/hardware/*.patch` → `hardware/interfaces/boot`（16.0 `tryGetService`，避免 HIDL 卡死黑屏）
5. `lunch` + `make bootimage`
6. 若设备树有 `scripts/repack-boot.sh`（**android-16.0**），再打一次 **legacy LZ4**（`lz4 -l`），与本地 `mka bootimage` 后的步骤相同。Soong 的 `BOARD_RAMDISK_USE_LZ4` 是 frame LZ4，Motokernel 解不开会黑屏。**android-12.1** 无此脚本，保持 Soong 产物。
7. 上传 artifact；可选发 GitHub Release

`boot.img` 按分区大小 padding，文件约 96 MB；实际 ramdisk 大小才影响 KernelSU 解包。

## Runner

**16.0** 必须用自建 `self-hosted`（GitHub-hosted 在 `make bootimage` 阶段会因内存被掐、runner 失联）。仓库 Settings → Actions → Runners 里要有一台在线、带 `self-hosted` 标签的机器（磁盘/内存需能编 AOSP 16）。12.1 仍默认 `ubuntu-24.04`。

## 刷入

```bash
fastboot boot boot_twrp_xpeng_*.img          # 一次性启动，不改写分区
# 或
fastboot flash boot boot_twrp_xpeng_*.img
```

`fastboot boot` 是一次性的：`ro.boot.slot_suffix` 仍是启动时的 slot。不要先 `fastboot set_active` 再立刻 `fastboot boot`。
