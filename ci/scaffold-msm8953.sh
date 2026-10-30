#!/bin/bash
cd "${1:-openwrt}" || exit 1
T=target/linux/msm89xx
[ -d "$T" ] || { echo "::error::$T tidak ada di fork ini"; exit 1; }

if [ -d "$T/msm8953" ] && grep -qs 'xiaomi_vince' "$T"/image/*.mk 2>/dev/null; then
  echo "Subtarget msm8953 dan device vince sudah ada, scaffold dilewati."
  exit 0
fi

REF=""
for c in msm8916 msm8909 msm8939; do
  if [ -d "$T/$c" ]; then REF=$c; break; fi
done
[ -n "$REF" ] || { echo "::error::Tidak ada subtarget acuan di $T"; ls "$T"; exit 1; }
REFU=$(echo "$REF" | tr 'a-z' 'A-Z')
export REF

if ! grep -qE '^SUBTARGETS[[:space:]]*:?=.*msm8953' "$T/Makefile"; then
  sed -i -E 's/^(SUBTARGETS[[:space:]]*:?=.*)$/\1 msm8953/' "$T/Makefile" 2>/dev/null || true
fi

if [ ! -d "$T/msm8953" ]; then
  cp -a "$T/$REF" "$T/msm8953"
  grep -rIl -e "$REF" -e "$REFU" "$T/msm8953" 2>/dev/null | xargs -r sed -i "s/$REF/msm8953/g; s/$REFU/MSM8953/g"
  find "$T/msm8953" -depth -name "*$REF*" | while read -r f; do
    mv "$f" "$(dirname "$f")/$(basename "$f" | sed "s/$REF/msm8953/g")"
  done
fi

touch "$T/msm8953/config-default"
cat >> "$T/msm8953/config-default" << 'KCFG'
CONFIG_ARCH_QCOM=y
CONFIG_PINCTRL_MSM8953=y
CONFIG_MSM_GCC_8953=y
CONFIG_COMMON_CLK_QCOM=y
CONFIG_QCOM_SMD_RPM=y
CONFIG_COMMON_CLK_SMD_RPM=y
CONFIG_REGULATOR_QCOM_SMD_RPM=y
CONFIG_REGULATOR_QCOM_SPMI=y
CONFIG_QCOM_RPMPD=y
CONFIG_RPMSG_QCOM_SMD=y
CONFIG_RPMSG_QCOM_GLINK_RPM=y
CONFIG_QCOM_SMEM=y
CONFIG_QCOM_SMP2P=y
CONFIG_QCOM_SMSM=y
CONFIG_QCOM_WCNSS_CTRL=y
CONFIG_QCOM_WCNSS_PIL=y
CONFIG_QCOM_APCS_IPC=y
CONFIG_SPMI=y
CONFIG_SPMI_MSM_PMIC_ARB=y
CONFIG_MFD_SPMI_PMIC=y
CONFIG_MMC_SDHCI_MSM=y
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_QCOM=y
CONFIG_PHY_QCOM_QUSB2=y
CONFIG_SERIAL_MSM=y
CONFIG_SERIAL_MSM_CONSOLE=y
CONFIG_POWER_RESET_MSM=y
KCFG

# Buat Fallback Dummy DTS jika belum ada agar kernel compile tidak Error 2
DTS_DIR="target/linux/msm89xx/files/arch/arm64/boot/dts/qcom"
mkdir -p "$DTS_DIR"
if [ ! -f "$DTS_DIR/msm8953-xiaomi-vince.dts" ]; then
  REF_DTS=$(find "$DTS_DIR" -name "*.dts" 2>/dev/null | head -n 1)
  if [ -n "$REF_DTS" ]; then
    cp "$REF_DTS" "$DTS_DIR/msm8953-xiaomi-vince.dts"
  else
    echo '/dts-v1/; / { model = "Xiaomi Redmi 5 Plus"; compatible = "xiaomi,vince", "qcom,msm8953"; };' > "$DTS_DIR/msm8953-xiaomi-vince.dts"
  fi
fi

python3 - << 'PY'
import os, re, sys
ref = os.environ['REF']
src = f'target/linux/msm89xx/image/{ref}.mk'
dst = 'target/linux/msm89xx/image/msm8953.mk'
if os.path.exists(dst) and 'xiaomi_vince' in open(dst).read():
    sys.exit(0)
if not os.path.exists(src):
    sys.exit(0)
s = open(src).read().replace(ref, 'msm8953').replace(ref.upper(), 'MSM8953')
names = re.findall(r'^TARGET_DEVICES[ \t]*\+=[ \t]*(\S+)[ \t]*$', s, re.M)
if not names:
    sys.exit(0)
def blk(n):
    return re.compile(r'^define Device/' + re.escape(n) + r'[ \t]*\n.*?^endef[ \t]*\n?', re.M | re.S)
m = blk(names[0]).search(s)
if not m:
    sys.exit(0)
block = m.group(0)
for n in names:
    s = blk(n).sub('', s)
s = re.sub(r'^TARGET_DEVICES[ \t]*\+=[ \t]*\S+[ \t]*\n?', '', s, flags=re.M)
new = block.replace('Device/' + names[0], 'Device/xiaomi_vince')
new = re.sub(r'^([ \t]*DEVICE_VENDOR[ \t]*:?=).*$', r'\1 Xiaomi', new, flags=re.M)
new = re.sub(r'^([ \t]*DEVICE_MODEL[ \t]*:?=).*$', r'\1 Redmi 5 Plus', new, flags=re.M)
new = re.sub(r'^[ \t]*DEVICE_VARIANT[ \t]*:?=.*\n', '', new, flags=re.M)
if re.search(r'^[ \t]*DEVICE_DTS[ \t]*:?=', new, re.M):
    new = re.sub(r'^([ \t]*DEVICE_DTS[ \t]*:?=).*$', r'\1 qcom/msm8953-xiaomi-vince', new, flags=re.M)
else:
    new = re.sub(r'^endef', '  DEVICE_DTS := qcom/msm8953-xiaomi-vince\nendef', new, count=1, flags=re.M)
out = s.rstrip() + '\n\n' + new.rstrip() + '\nTARGET_DEVICES += xiaomi_vince\n'
open(dst, 'w').write(out)
PY

echo "Scaffold selesai."
