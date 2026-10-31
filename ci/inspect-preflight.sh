#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "========================================================="
echo "=== MEMULAI PENGECEKAN PRA-BUILD KETAT (REDMI 5 PLUS) ==="
echo "========================================================="
ERR=0

# 1. Cek Subtarget MSM8953
if [ ! -d "target/linux/msm89xx/msm8953" ]; then
    echo "::error::[PRA-BUILD GAGAL] Subtarget target/linux/msm89xx/msm8953 TIDAK DITEMUKAN! Porting kernel msm8953 belum siap."
    ERR=1
fi

# 2. Cek Registrasi Device xiaomi_vince
if ! grep -rq 'xiaomi_vince' target/linux/msm89xx/image/; then
    echo "::error::[PRA-BUILD GAGAL] Device 'xiaomi_vince' TIDAK TERDAFTAR di target/linux/msm89xx/image/! Image firmware tidak akan terbentuk."
    ERR=1
fi

# 3. Cek Keberadaan DTS Vince (msm8953-xiaomi-vince.dts)
DTS_EXISTS=$(find target/linux/msm89xx/ -name "*msm8953-xiaomi-vince*.dts" 2>/dev/null)
if [ -z "$DTS_EXISTS" ]; then
    echo "::warning::[PERINGATAN DTS] File msm8953-xiaomi-vince.dts tidak ditemukan di target tree OpenWrt. Memastikan ketersediaan di kernel tree..."
fi

# 4. Verifikasi Konfigurasi (.config) Khusus Vince
if ! grep -q '^CONFIG_TARGET_msm89xx=y' .config; then
    echo "::error::[PRA-BUILD GAGAL] Target msm89xx tidak terpilih di file .config!"
    ERR=1
fi

if ! grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config; then
    echo "::error::[PRA-BUILD GAGAL] Device Redmi 5 Plus (xiaomi_vince) tidak aktif di file .config!"
    ERR=1
fi

if [ "$ERR" -ne 0 ]; then
    echo ""
    echo "************************************************************************"
    echo "   BUILD DIHENTIKAN: PERANGKAT ATAU CONFIG TIDAK SESUAI REDMI 5 PLUS    "
    echo "   Silakan periksa pesan error di atas sebelum melakukan build ulang.   "
    echo "************************************************************************"
    exit 1
fi

echo "::notice::[PRA-BUILD SUKSES] Seluruh syarat konfigurasi Xiaomi Redmi 5 Plus (Vince) TERVERIFIKASI!"
