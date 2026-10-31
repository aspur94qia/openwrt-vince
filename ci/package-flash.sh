#!/bin/bash
OUT="${GITHUB_WORKSPACE:-/tmp}/flash-out"
mkdir -p "$OUT"
cd "${1:-openwrt}" || exit 1
find bin/targets -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.bin' -o -name '*.zip' -o -name 'sha256sums' -o -name '*.manifest' \) -exec cp -v {} "$OUT"/ \;
{
cat << 'DOC'
# Panduan Flash OpenWrt Xiaomi Redmi 5 Plus (Vince)
1. Bootloader harus Unlock (Mi Unlock).
2. Fastboot flash boot qcom-msm8953-lk2nd.img
3. Fastboot flash userdata <file_rootfs.img>
4. Fastboot reboot
DOC
echo "## Hasil Build Files"
( cd "$OUT" && ls -lh )
} > "$OUT/FLASH.md"
echo "Paket flash disiapkan di $OUT"
