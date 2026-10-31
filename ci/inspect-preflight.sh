#!/bin/bash
cd "${1:-openwrt}" || exit 1
echo "================================================================="
echo "=== PENGECEKAN PRA-BUILD KETAT & TEST KOMPILASI (REDMI 5 PLUS) ==="
echo "================================================================="
ERR=0

if [ ! -d "target/linux/msm89xx/msm8953" ]; then
    echo "::error::[PRA-BUILD GAGAL] Subtarget target/linux/msm89xx/msm8953 TIDAK DITEMUKAN!"
    ERR=1
fi

if ! grep -rq 'xiaomi_vince' target/linux/msm89xx/image/; then
    echo "::error::[PRA-BUILD GAGAL] Device 'xiaomi_vince' TIDAK TERDAFTAR di target/linux/msm89xx/image/!"
    ERR=1
fi

if ! grep -q '^CONFIG_TARGET_msm89xx=y' .config || ! grep -q '^CONFIG_TARGET_msm89xx_msm8953_DEVICE_xiaomi_vince=y' .config; then
    echo "::error::[PRA-BUILD GAGAL] Target atau Device Vince tidak terkunci di .config!"
    ERR=1
fi

if [ "$ERR" -ne 0 ]; then
    echo "::error::Pre-flight awal gagal! Menghentikan workflow."
    exit 1
fi

echo "::notice::Menjalankan uji kompilasi kernel target/linux..."
make target/linux/compile -j"$(nproc)" V=s > preflight-kernel.log 2>&1
K_RC=${PIPESTATUS[0]}

if [ "$K_RC" -ne 0 ]; then
    echo "::error::[PRA-BUILD GAGAL] Kompilasi C kernel target/linux BERMASALAH! Ada kode/patch yang crash."
    echo "------------------ DETAIL ERROR KERNEL ------------------"
    grep -nE 'error:|Error [0-9]+|\*\*\* |ERROR:' preflight-kernel.log | tail -n 30
    echo "--------------------------------------------------------"
    exit 1
fi

echo "::notice::[PRA-BUILD SUKSES 100%] Uji kompilasi kernel lulus! Aman untuk melanjutkan build firmware."
