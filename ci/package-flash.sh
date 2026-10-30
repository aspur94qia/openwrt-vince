#!/bin/bash
OUT="$GITHUB_WORKSPACE/flash-out"; mkdir -p "$OUT"
cd "${1:-openwrt}" || exit 1
find bin/targets -type f \( -name '*.img' -o -name '*.img.gz' -o -name '*.bin' -o -name '*.zip' -o -name 'sha256sums' -o -name '*.manifest' \) -exec cp -v {} "$OUT"/ \;
{
cat << 'DOC'
# Cara flash OpenWrt Vince

1. Backup partisi Boot dan System lewat Recovery (TWRP / OrangeFox).
2. Wipe Data, Cache, Dalvik.
3. Select Install Image:
   - Flash file `...-boot.img` ke partisi **Boot**.
   - Flash file `...-rootfs.img` ke partisi **System Image**.
4. Reboot System.
DOC
echo "## File hasil build"
( cd "$OUT" && ls -lh )
} > "$OUT/FLASH.md"
echo "Paket flash siap di $OUT"
