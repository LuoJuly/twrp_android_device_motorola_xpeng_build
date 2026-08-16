# TWRP xpeng build (GitHub Actions + local)

GitHub Actions and local build notes for Motorola **xpeng** (XT2175-1 G200 5G / XT2175-2 Edge S30).

Output is always **recovery-as-boot** `boot.img` (~96 MB padded). Device tree: [LuoJuly/twrp_android_device_motorola_xpeng](https://github.com/LuoJuly/twrp_android_device_motorola_xpeng).

| Tree | Device-tree branch | Manifest | Lunch | Host JDK | About string / artifact |
|---|---|---|---|---|---|
| **12.1** (stock) | `android-12.1` | [minimal-manifest-twrp](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp) `twrp-12.1` | `twrp_xpeng-eng` | 11 | `3.7.1_12-0_stock_by LuoJuly` / `boot_twrp_xpeng_stock_3.7.1_a12.1.img` |
| **16.0** (Lineage 23.2) | `android-16.0` | [TWRP-Test](https://github.com/TWRP-Test/platform_manifest_twrp_aosp) `twrp-16.0` | `twrp_xpeng-bp2a-eng` | 17 | `3.7.1_16-0_lineage_by LuoJuly` / `boot_twrp_xpeng_lineage_3.7.1_a16.0.img` |

Full local steps: [docs/local-android-12.1.md](docs/local-android-12.1.md) · [docs/local-android-16.0.md](docs/local-android-16.0.md)

---

## GitHub Actions

Run **Actions → Build TWRP 12.1 / 16.0 → Run workflow**. Owner-only.

| Input | Notes |
|---|---|
| `device_tree_ref` | Device-tree branch (defaults in the table above) |
| `lunch_combo` | Override lunch |
| `publish_release` | Upload a GitHub Release (default on) |
| `runner` | **12.1** defaults to `ubuntu-24.04`. **16.0** defaults to `self-hosted` (GitHub-hosted OOM / runner disconnect during `make bootimage`) |

Tags look like `v3.7.1_12-0-YYYYMMDD` / `v3.7.1_16-0-YYYYMMDD` (`-r<run>` if the tag exists). 12.1 releases are **not** marked Latest.

Pipeline: `repo init --depth=1` → sync → clone device tree → `twrp.dependencies` → `scripts/apply-device-patches.sh` → `lunch` + `make bootimage` → on 16.0, `scripts/repack-boot.sh` (Motokernel **legacy LZ4** `lz4 -l`). 12.1 has no repack script.

Register a [self-hosted runner](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners) with the `self-hosted` label before running 16.0.

---

## Host packages (both trees)

Linux x86_64 (Ubuntu 22.04 / 24.04). Install `repo`:

```bash
mkdir -p ~/bin
curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH="$HOME/bin:$PATH"
```

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git-core gnupg flex bison build-essential zip unzip curl wget \
  zlib1g-dev libc6-dev-i386 lib32z1-dev lib32ncurses-dev \
  x11proto-core-dev libx11-dev libgl1-mesa-dev libxml2-utils \
  xsltproc python3 python-is-python3 gcc-multilib g++-multilib \
  libncurses-dev libssl-dev bc rsync schedtool pngcrush imagemagick \
  lzop liblz4-tool ccache tree libxml2 squashfs-tools \
  libgtk-3-dev libglu1-mesa-dev gperf cpio
```

| | 12.1 | 16.0 |
|---|---|---|
| JDK | 11 (`openjdk-11-jdk` or Temurin 11) | 17 (tree also ships `prebuilts/jdk/jdk21`) |
| RAM / disk | ~16 GB / ~80 GB | 32 GB+ / ~150 GB+ |
| Workspace | `~/android/twrp-12.1` | `~/android/twrp-16.0` |

Soong **cannot follow a symlink** for `device/motorola/xpeng` — `rsync`/copy the device tree, do not `ln -s`.

This repo’s `scripts/apply-device-patches.sh` and `scripts/convert.sh` match Actions. Clone it next to the device tree:

```bash
git clone https://github.com/LuoJuly/twrp_android_device_motorola_xpeng_build.git ~/android/twrp_android_device_motorola_xpeng_build
git clone -b android-12.1 https://github.com/LuoJuly/twrp_android_device_motorola_xpeng.git ~/android/twrp_android_device_motorola_xpeng
# 16.0: git -C ~/android/twrp_android_device_motorola_xpeng checkout android-16.0
```

---

## Local: Android 12.1

See [docs/local-android-12.1.md](docs/local-android-12.1.md) for the same steps in one page.

```bash
mkdir -p ~/android/twrp-12.1 && cd ~/android/twrp-12.1
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

mkdir -p device/motorola
rsync -a --delete --exclude '.git' \
  ~/android/twrp_android_device_motorola_xpeng/ device/motorola/xpeng/

# twrp-12.1 manifest already has TeamWin android_device_qcom_common (gpt-utils).
# No twrp.dependencies on this branch.

bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/apply-device-patches.sh \
  "$PWD" device/motorola/xpeng

. build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_xpeng-eng
mka bootimage
```

Output: `out/target/product/xpeng/boot.img`  
Ramdisk is slimmed by `BOARD_RECOVERY_IMAGE_PREPARE` → `recovery/slim-ramdisk.sh`. Do **not** run `repack-boot.sh` (16.0 only).

Patches applied: `patches/*.patch` (0001–0006, 0009–0011, 0013–0015) → `bootable/recovery`; `patches/init/0012` → `system/core`; `patches/vibrator/0008` → QTI vibrator; `patches/gpt-utils/0007` → `device/qcom/common`. Overlay: delayed `keystore2` + VINTF `manifest.xml` under `recovery/root/`.

---

## Local: Android 16.0

See [docs/local-android-16.0.md](docs/local-android-16.0.md).

```bash
mkdir -p ~/android/twrp-16.0 && cd ~/android/twrp-16.0
repo init --depth=1 -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git -b twrp-16.0
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

git -C ~/android/twrp_android_device_motorola_xpeng checkout android-16.0
mkdir -p device/motorola
rsync -a --delete --exclude '.git' \
  ~/android/twrp_android_device_motorola_xpeng/ device/motorola/xpeng/

bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/convert.sh \
  device/motorola/xpeng/twrp.dependencies
# roomservice: TeamWin twrp-common (android-14) + qcom common (android-12.1 gpt-utils)
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --current-branch --no-tags

bash ~/android/twrp_android_device_motorola_xpeng_build/scripts/apply-device-patches.sh \
  "$PWD" device/motorola/xpeng
# recovery patches, gpt-utils/0007, vibrator/0008, hardware/0006 (HIDL tryGetService)

. build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
lunch twrp_xpeng-bp2a-eng
mka bootimage

# Required: Soong LZ4 frames will not unpack on Motokernel 5.4 (black screen).
export ANDROID_BUILD_TOP="$PWD"
bash device/motorola/xpeng/scripts/repack-boot.sh
```

Output: `out/target/product/xpeng/boot.img`  
Kernel: ReSukiSU `lineage-23.2-ReSukiSU` (`5.4.302-moto-g37469fe9fcdd`). Decrypt is Keymaster 4.1 (not KeyMint/Weaver).

---

## Flash

```bash
fastboot boot boot_twrp_xpeng_*.img          # one-shot, does not rewrite the slot
# or
fastboot flash boot boot_twrp_xpeng_*.img
```

`fastboot boot` is one-shot: `ro.boot.slot_suffix` stays the launch slot. Do not `fastboot set_active` and then immediately `fastboot boot`.
