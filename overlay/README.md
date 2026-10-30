# Overlay port Vince

Isi folder ini DISALIN ke root source OpenWrt sebelum scaffold dan defconfig.
Kalau scaffold otomatis kurang tepat, taruh file yang benar di sini (menimpa hasil scaffold):

- overlay/target/linux/msm89xx/msm8953/target.mk
- overlay/target/linux/msm89xx/msm8953/config-default
- overlay/target/linux/msm89xx/image/msm8953.mk
- overlay/files/lib/firmware/...   (blob WiFi dari stock, pakai repo PRIVATE)

Patch tambahan: overlay-patches/*.patch (di-apply dengan git apply).
