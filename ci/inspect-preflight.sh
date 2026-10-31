#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "=== MEMULAI PRE-FLIGHT INSPECTION HARIAN ==="
ERR=0

# 1. Cek Target & Subtarget
[ -d "target/linux/msm89xx/msm8953" ] || { echo "::error::Subtarget msm8953 tidak ditemukan!"; ERR=1; }

# 2. Cek Device Vince di Makefile image
grep -rq 'xiaomi_vince' target/linux/msm89xx/image/ || { echo "::error::Device xiaomi_vince tidak terdaftar di image/*.mk!"; ERR=1; }

# 3. Cek Keberadaan DTS Vince (Kernel / Files)
DTS_FOUND=$(find target/linux/msm89xx/ -name "*msm8953-xiaomi-vince*.dts" 2>/dev/null)
if [ -z "$DTS_FOUND" ]; then
    echo "::warning::DTS msm8953-xiaomi-vince tidak ditemukan di folder target tree. Memastikan via config/kernel."
fi

# 4. Verifikasi Konfigurasi (.config)
grep -q '^CONFIG_TARGET_msm89xx=y' .config || { echo "::error::CONFIG_TARGET_msm89xx tidak aktif di .config!"; ERR=1; }
grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config || { echo "::error::Device Vince tidak terpilih di .config!"; ERR=1; }

# 5. Cek kelengkapan Toolchain
[ -f "scripts/feeds" ] || { echo "::error::Script feeds tidak ditemukan!"; ERR=1; }

if [ "$ERR" -ne 0 ]; then
    echo "::error::Pre-flight Inspection GAGAL! Build dibatalkan untuk menghemat waktu."
    exit 1
fi

echo "::notice::Pre-flight Inspection SUKSES! Semua struktur file dan konfigurasi valid."
