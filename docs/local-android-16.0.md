# Local TWRP 16.0 (xpeng)

Matches GitHub Action **Build TWRP 16.0 (xpeng)** and the `android-16.0` device-tree branch (LineageOS 23.2 / Android 16 QPR2).

## Environment

| Item | Value |
|---|---|
| OS | Linux x86_64, Ubuntu 22.04 / 24.04 |
| JDK | **17** on the host (the tree also has `prebuilts/jdk/jdk21`) |
| RAM / disk | 32 GB+ RAM, ~150 GB+ disk (AOSP 16). GitHub-hosted runners OOM here |
| `repo` | [git-repo](https://gerrit.googlesource.com/git-repo) in `~/bin` |
| Manifest | `https://github.com/TWRP-Test/platform_manifest_twrp_aosp` `-b twrp-16.0` |
| Device tree | `LuoJuly/twrp_android_device_motorola_xpeng` **`android-16.0`** |
| Lunch | `twrp_xpeng-bp2a-eng` (product-release-variant; not `twrp_xpeng-eng`) |
| Target | `bootimage` then **`scripts/repack-boot.sh`** |
| About | `3.7.1_16-0_lineage_by LuoJuly` |
| Kernel | ReSukiSU `lineage-23.2-ReSukiSU` (`5.4.302-moto-g37469fe9fcdd`) |
| Crypto | QCOM FBE **Keymaster 4.1** (not KeyMint / Weaver) |

Host packages: see the [README](../README.md#host-packages-both-trees).

`twrp.dependencies`:

- `TeamWin/android_device_qcom_twrp-common` → `device/qcom/twrp-common` (`android-14`)
- `TeamWin/android_device_qcom_common` → `device/qcom/common` (`android-12.1`, gpt-utils)

Soong **cannot follow a symlink** for `device/motorola/xpeng`.

## Steps

```bash
# 0. Tools
export PATH="$HOME/bin:$PATH"
java -version   # 17.x

# 1. Device tree (android-16.0)
git clone -b android-16.0 \
  https://github.com/LuoJuly/twrp_android_device_motorola_xpeng.git \
  ~/android/twrp_android_device_motorola_xpeng
git clone https://github.com/LuoJuly/twrp_android_device_motorola_xpeng_build.git \
  ~/android/twrp_android_device_motorola_xpeng_build

# 2. TWRP-Test source
mkdir -p ~/android/twrp-16.0 && cd ~/android/twrp-16.0
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

# 3. Place device tree
mkdir -p device/motorola
rsync -a --delete --exclude '.git' \
  ~/android/twrp_android_device_motorola_xpeng/ device/motorola/xpeng/

# 4. Extra repos from twrp.dependencies
bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/convert.sh \
  device/motorola/xpeng/twrp.dependencies
cat .repo/local_manifests/roomservice.xml
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

# 5. Patches (same mapping as Actions)
bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/apply-device-patches.sh \
  "$PWD" device/motorola/xpeng

# 6. Build
. build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_xpeng-bp2a-eng
mka bootimage

# 7. Required: Motokernel 5.4 only unpacks legacy LZ4 (lz4 -l).
#    Soong BOARD_RAMDISK_USE_LZ4 writes a modern frame → black screen.
export ANDROID_BUILD_TOP="$PWD"
bash device/motorola/xpeng/scripts/repack-boot.sh
```

Output: `out/target/product/xpeng/boot.img`

`repack-boot.sh` also re-runs `slim-ramdisk.sh` and rebuilds the boot image with `lz4 -l`.

## Patches this tree applies

| Patch | Destination |
|---|---|
| `patches/0001`–`0005`, `0009`–`0011` | `bootable/recovery` (0011 = OpenAES C23 `isaac_rand`) |
| `patches/hardware/0006` | `hardware/interfaces/boot` (`tryGetService`, avoids HIDL hang / black screen) |
| `patches/gpt-utils/0007` | `device/qcom/common` |
| `patches/vibrator/0008` | `vendor/qcom/opensource/vibrator` |

Delayed keystore2 + VINTF skeleton: `recovery/root/`.

Device-tree flags already set: `PRODUCT_CHECK_PREBUILT_MAX_PAGE_SIZE := false`, `OVERRIDE_ENABLE_UFFD_GC := false`.

## Flash

```bash
fastboot boot out/target/product/xpeng/boot.img
# or
device/motorola/xpeng/scripts/enter-twrp.sh boot
```
