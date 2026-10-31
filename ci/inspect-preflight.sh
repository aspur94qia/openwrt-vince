#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "=== PENGECEKAN PRA-BUILD (PRE-FLIGHT) ==="
ERR=0

# 1. Cek keberadaan subtarget msm8953
[ -d "target/linux/msm89xx/msm8953" ] || { echo "::error::Subtarget msm8953 tidak ada!"; ERR=1; }

# 2. Cek device vince di image Makefile
grep -rq 'xiaomi_vince' target/linux/msm89xx/image/ || { echo "::error::Device xiaomi_vince tidak terdefinisi di image Makefile!"; ERR=1; }

# 3. Verifikasi konfigurasi target di .config
grep -q '^CONFIG_TARGET_msm89xx=y' .config || { echo "::error::CONFIG_TARGET_msm89xx tidak aktif!"; ERR=1; }
grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config || { echo "::error::Device Vince tidak aktif di .config!"; ERR=1; }

if [ "$ERR" -ne 0 ]; then
    echo "::error::Pre-flight gagal! Build dihentikan demi menghemat waktu."
    exit 1
fi

echo "::notice::Pre-flight sukses! Semua target & konfigurasi valid."
