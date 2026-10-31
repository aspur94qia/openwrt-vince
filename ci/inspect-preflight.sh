#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "================================================================="
echo "=== PENGECEKAN PRA-BUILD TOTAL (TOOLCHAIN & CONFIG VINCE) ==="
echo "================================================================="
ERR=0

if [ ! -d "target/linux/msm89xx/msm8953" ]; then
    echo "::error::[PRE-BUILD GAGAL] Subtarget target/linux/msm89xx/msm8953 TIDAK DITEMUKAN!"
    ERR=1
fi

if ! grep -rq 'xiaomi_vince' target/linux/msm89xx/image/; then
    echo "::error::[PRE-BUILD GAGAL] Device 'xiaomi_vince' TIDAK TERDAFTAR di target/linux/msm89xx/image/!"
    ERR=1
fi

if ! grep -q '^CONFIG_TARGET_msm89xx=y' .config; then
    echo "::error::[PRE-BUILD GAGAL] Target msm89xx tidak terpilih di .config!"
    ERR=1
fi

if ! grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config; then
    echo "::error::[PRE-BUILD GAGAL] Device Vince tidak aktif di .config!"
    ERR=1
fi

GCC_CHECK=$(find staging_dir/toolchain-* -name "aarch64-openwrt-linux-musl-gcc" -o -name "aarch64-openwrt-linux-gcc" 2>/dev/null | head -n 1)
if [ -z "$GCC_CHECK" ]; then
    echo "::error::[PRE-BUILD GAGAL] Cross-compiler aarch64 belum ter-compile atau tidak ditemukan di staging_dir!"
    ERR=1
else
    echo "::notice::Compiler terverifikasi: $GCC_CHECK"
fi

if [ "$ERR" -ne 0 ]; then
    echo "::error::Pre-flight gagal! Menghentikan workflow."
    exit 1
fi

echo "::notice::[PRE-BUILD SUKSES 100%] Toolchain & Konfigurasi Xiaomi Redmi 5 Plus SIAP!"
