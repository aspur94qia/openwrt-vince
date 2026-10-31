#!/bin/bash
OUT="$GITHUB_WORKSPACE/flash-out"; mkdir -p "$OUT"
cd "${1:-openwrt}" || exit 1
find bin/targets -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.bin' -o -name '*.zip' -o -name 'sha256sums' -o -name '*.manifest' \) -exec cp -v {} "$OUT"/ \;
{
cat << 'DOC'
# Cara flash OpenWrt Vince (BELUM DITES di perangkat nyata)

Asumsi: image fork memakai alur lk2nd + rootfs (seperti OpenStick MSM8916).
Alur ini belum terbukti untuk Vince. Cek artifact port-info untuk detail format image.

1. Bootloader harus sudah di-unlock (Mi Unlock).
2. Siapkan fastboot ROM MIUI Vince (stok) untuk jaga-jaga pemulihan.
3. Backup partisi boot dan recovery dulu (lewat TWRP).
4. Ambil image lk2nd untuk MSM8953 (qcom-msm8953-lk2nd.img) dari bagian
   "Pre-built images" di wiki postmarketOS halaman xiaomi-vince.
5. Masuk fastboot, lalu:

   fastboot flash boot qcom-msm8953-lk2nd.img
   fastboot flash userdata <file rootfs .img dari build ini>
   fastboot reboot

   (Jangan menimpa partisi system kalau belum yakin: userdata lebih aman dipulihkan.)
6. Setelah boot (tanpa LCD):
   - WiFi: SSID dan password sesuai secret WIFI_KEY (default vince12345), buka http://192.168.1.1
   - Atau lewat kabel USB: interface usb0, lalu ssh root@192.168.1.1
7. Jika tidak boot: masuk fastboot lagi (Vol- + Power) dan flash ulang boot/recovery dari backup.

DOC
echo "## File hasil build"
( cd "$OUT" && ls -lh )
} > "$OUT/FLASH.md"
echo "Paket flash siap di $OUT"
