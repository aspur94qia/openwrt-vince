#!/bin/bash
OUT="$GITHUB_WORKSPACE/flash-out"; mkdir -p "$OUT"
cd "${1:-openwrt}" || exit 1
find bin/targets -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.bin' -o -name '*.zip' -o -name 'sha256sums' -o -name '*.manifest' \) -exec cp -v {} "$OUT"/ \;
{
cat << 'DOC'
# Cara Flash OpenWrt Xiaomi Redmi 5 Plus (Vince)

1. Bootloader harus ter-unlock (Mi Unlock).
2. Siapkan lk2nd image untuk MSM8953 (qcom-msm8953-lk2nd.img).
3. Masuk Fastboot Mode (Vol Down + Power).
4. Eksekusi flash via Fastboot:
   fastboot flash boot qcom-msm8953-lk2nd.img
   fastboot flash userdata <file_rootfs.img>
   fastboot reboot
5. Akses Router:
   - Web UI: http://192.168.1.1 (Wi-Fi SSID: OpenWrt-Vince / Pass: vince12345)
   - SSH: ssh root@192.168.1.1 (Pass: vince12345 atau via USB Gadget `usb0`)
DOC
echo "## File Hasil Build"
( cd "$OUT" && ls -lh )
} > "$OUT/FLASH.md"
echo "Paket flash siap di $OUT"
