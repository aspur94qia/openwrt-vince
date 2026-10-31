#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "================================================================="
echo "=== PENGECEKAN PRA-BUILD KETAT VERIFIKASI FILE (REDMI 5 PLUS) ==="
echo "================================================================="
ERR=0

# 1. Cek Subtarget msm8953
if [ ! -d "target/linux/msm89xx/msm8953" ]; then
    echo "::error::[PRA-BUILD GAGAL] Subtarget target/linux/msm89xx/msm8953 TIDAK DITEMUKAN!"
    ERR=1
fi

# 2. Cek Device xiaomi_vince di Makefile
if ! grep -rq 'xiaomi_vince' target/linux/msm89xx/image/; then
    echo "::error::[PRA-BUILD GAGAL] Device 'xiaomi_vince' TIDAK TERDAFTAR di target/linux/msm89xx/image/!"
    ERR=1
fi

# 3. Verifikasi Konfigurasi .config
if ! grep -q '^CONFIG_TARGET_msm89xx=y' .config; then
    echo "::error::[PRA-BUILD GAGAL] Target msm89xx tidak terpilih di .config!"
    ERR=1
fi

if ! grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config; then
    echo "::error::[PRA-BUILD GAGAL] Device Vince tidak aktif di .config!"
    ERR=1
fi

if [ "$ERR" -ne 0 ]; then
    echo "::error::[PRA-BUILD GAGAL] Syarat dasar tidak terpenuhi. Menghentikan workflow!"
    exit 1
fi

echo "::notice::[PRA-BUILD SUKSES 100%] Seluruh struktur target, device, dan .config Redmi 5 Plus valid!"
