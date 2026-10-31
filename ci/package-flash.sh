#!/bin/bash
OUT="$GITHUB_WORKSPACE/flash-out"; mkdir -p "$OUT"
cd "${1:-openwrt}" || exit 1
find bin/targets -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.bin' -o -name '*.zip' -o -name 'sha256sums' -o -name '*.manifest' \) -exec cp -v {} "$OUT"/ \;
{
cat << 'DOC'
# Panduan Flash OpenWrt Xiaomi Redmi 5 Plus (Vince)

1. Pastikan Bootloader sudah Unlock (Mi Unlock).
2. Siapkan file lk2nd image untuk MSM8953 (qcom-msm8953-lk2nd.img).
3. Masuk Fastboot Mode (Volume Bawah + Power).
4. Eksekusi perintah flash via Fastboot:
   fastboot flash boot qcom-msm8953-lk2nd.img
   fastboot flash userdata <file_rootfs.img>
   fastboot reboot
5. Akses Router:
   - Web UI: http://192.168.1.1 (Wi-Fi SSID: OpenWrt-Vince / Pass: vince12345)
   - SSH: ssh root@192.168.1.1 (Pass: vince12345)
DOC
echo "## Hasil Build Files"
( cd "$OUT" && ls -lh )
} > "$OUT/FLASH.md"
echo "Paket flash disiapkan di $OUT"
