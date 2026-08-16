# Local TWRP 12.1 (xpeng)

Matches GitHub Action **Build TWRP 12.1 (xpeng)** and the `android-12.1` device-tree branch.

## Environment

| Item | Value |
|---|---|
| OS | Linux x86_64, Ubuntu 22.04 / 24.04 |
| JDK | **11** (`openjdk-11-jdk` or Temurin 11) |
| RAM / disk | ~16 GB / ~80 GB |
| `repo` | [git-repo](https://gerrit.googlesource.com/git-repo) in `~/bin` |
| Manifest | `https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp` `-b twrp-12.1` |
| Device tree | `LuoJuly/twrp_android_device_motorola_xpeng` **`android-12.1`** |
| Lunch | `twrp_xpeng-eng` |
| Target | `bootimage` → `out/target/product/xpeng/boot.img` |
| About | `3.7.1_12-0_stock_by LuoJuly` (`TW_DEVICE_VERSION := 0_stock_by LuoJuly`) |
| Kernel | Stock ReSukiSU `5.4.302-s3rxc32.33-8-25-ReSukiSU` (`prebuilt/kernel`) |
| Blobs | Stock `android-12-release-S3RXC32.33-8-29` |

Host packages: see the [README](../README.md#host-packages-both-trees).

`twrp-12.1` already vendors `TeamWin/android_device_qcom_common` (gpt-utils). This branch has **no** `twrp.dependencies`.

Do **not** symlink the device tree into `device/motorola/xpeng` (Soong). `rsync` or copy.

## Steps

```bash
# 0. Tools
export PATH="$HOME/bin:$PATH"
java -version   # 11.x

# 1. Device tree
git clone -b android-12.1 \
  https://github.com/LuoJuly/twrp_android_device_motorola_xpeng.git \
  ~/android/twrp_android_device_motorola_xpeng
git clone https://github.com/LuoJuly/twrp_android_device_motorola_xpeng_build.git \
  ~/android/twrp_android_device_motorola_xpeng_build

# 2. TWRP source
mkdir -p ~/android/twrp-12.1 && cd ~/android/twrp-12.1
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

# 3. Place device tree
mkdir -p device/motorola
rsync -a --delete --exclude '.git' \
  ~/android/twrp_android_device_motorola_xpeng/ device/motorola/xpeng/

# 4. Patches (same mapping as Actions)
bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/apply-device-patches.sh \
  "$PWD" device/motorola/xpeng

# 5. Build
. build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_xpeng-eng
mka bootimage
```

`BOARD_RECOVERY_IMAGE_PREPARE` runs `recovery/slim-ramdisk.sh`. There is **no** `scripts/repack-boot.sh` on 12.1 — keep the Soong `boot.img`.

## Patches this tree applies

| Patch | Destination |
|---|---|
| `patches/0001`–`0006`, `0009`–`0011`, `0013`–`0015` | `bootable/recovery` |
| `patches/init/0012` | `system/core` (`fs_mgr` skip existing mapper) |
| `patches/vibrator/0008` | `vendor/qcom/opensource/vibrator` (`fcntl.h`) |
| `patches/gpt-utils/0007` | `device/qcom/common` (backup GPT commit) |

`0014` = default timezone `CST-8`. `0015` = `/misc` fstab fallback for BootControl/FBE.  
Delayed keystore2 + framework VINTF skeleton ship in `recovery/root/` (not a numbered patch).

## Flash

```bash
fastboot boot out/target/product/xpeng/boot.img
```
