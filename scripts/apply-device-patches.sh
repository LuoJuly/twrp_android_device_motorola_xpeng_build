#!/usr/bin/env bash
# Apply device-tree patches/ onto a synced TWRP source tree.
# Mirrors Action-TWRP-Builder scripts/local-build.sh apply_device_patches.
#
# Usage: apply-device-patches.sh <twrp-root> <device-path>
#   patches/*.patch            -> bootable/recovery
#   patches/vold/*.patch       -> system/vold
#   patches/vibrator/*.patch   -> vendor/qcom/opensource/vibrator
#   patches/init/*.patch       -> system/core
#   patches/gpt-utils/*.patch  -> device/qcom/common
#
# patches/disabled/ is never applied.
set -euo pipefail

WORKSPACE="${1:?twrp source root}"
DEVICE_PATH="${2:?device path relative to twrp root}"
PATCH_DIR="${WORKSPACE}/${DEVICE_PATH}/patches"

apply_one() {
  local dest="$1"
  local patch="$2"
  local label="$3"

  if [[ ! -d "$dest" ]]; then
    echo "==> Skip ${label}: destination missing (${dest})"
    return 0
  fi
  echo "==> Applying ${label} -> ${dest#"${WORKSPACE}"/}"
  if patch -d "$dest" -p1 -N --dry-run -i "$patch" >/dev/null 2>&1; then
    patch -d "$dest" -p1 -N -i "$patch"
  else
    echo "    (already applied or not applicable — skip)"
  fi
}

[[ -d "$PATCH_DIR" ]] || {
  echo "==> No patches/ in ${DEVICE_PATH}"
  exit 0
}

shopt -s nullglob
for p in "${PATCH_DIR}"/*.patch; do
  apply_one "${WORKSPACE}/bootable/recovery" "$p" "$(basename "$p")"
done
for p in "${PATCH_DIR}/vold"/*.patch; do
  apply_one "${WORKSPACE}/system/vold" "$p" "vold/$(basename "$p")"
done
for p in "${PATCH_DIR}/vibrator"/*.patch; do
  apply_one "${WORKSPACE}/vendor/qcom/opensource/vibrator" "$p" "vibrator/$(basename "$p")"
done
for p in "${PATCH_DIR}/init"/*.patch; do
  apply_one "${WORKSPACE}/system/core" "$p" "init/$(basename "$p")"
done
for p in "${PATCH_DIR}/gpt-utils"/*.patch; do
  apply_one "${WORKSPACE}/device/qcom/common" "$p" "gpt-utils/$(basename "$p")"
done
shopt -u nullglob
echo "==> Device patches done"
