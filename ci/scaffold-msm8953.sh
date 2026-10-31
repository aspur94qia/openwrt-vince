#!/bin/bash
cd "${1:-openwrt}" || exit 1
T=target/linux/msm89xx
if [ ! -d "$T" ]; then
  echo "::error::[PRE-BUILD GAGAL] Direktori $T tidak ditemukan di fork ini!"
  exit 1
fi

REF=""
for c in msm8916 msm8909 msm8939; do
  if [ -d "$T/$c" ]; then REF=$c; break; fi
done

if [ -z "$REF" ]; then
  echo "::error::[PRE-BUILD GAGAL] Tidak ditemukan subtarget acuan di $T!"
  exit 1
fi

REFU=$(echo "$REF" | tr 'a-z' 'A-Z')
export REF

if ! grep -qE '^SUBTARGETS[[:space:]]*:?=.*msm8953' "$T/Makefile"; then
  if grep -qE '^SUBTARGETS.*\\$' "$T/Makefile"; then
    echo "::warning::SUBTARGETS multi-baris, tambahkan msm8953 manual lewat overlay"
  else
    sed -i -E 's/^(SUBTARGETS[[:space:]]*:?=.*)$/\1 msm8953/' "$T/Makefile"
  fi
fi

if [ ! -d "$T/msm8953" ]; then
  cp -a "$T/$REF" "$T/msm8953"
  grep -rIl -e "$REF" -e "$REFU" "$T/msm8953" 2>/dev/null | xargs -r sed -i "s/$REF/msm8953/g; s/$REFU/MSM8953/g"
  find "$T/msm8953" -depth -name "*$REF*" | while read -r f; do
    mv "$f" "$(dirname "$f")/$(basename "$f" \vert{} sed "s/$REF/msm8953/g")"
  done
fi

if ! grep -q 'CONFIG_PINCTRL_MSM8953' "$T/msm8953/config-default" 2>/dev/null; then
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
fi

python3 - << 'PY'
import glob, os, re, sys
ref = os.environ['REF']
img = 'target/linux/msm89xx/image'
own = f'{img}/{ref}.mk'
dst = f'{img}/msm8953.mk'

def read(p):
    with open(p, encoding='utf-8', errors='ignore') as f:
        return f.read()

def has_dev(p):
    return os.path.isfile(p) and re.search(r'^TARGET_DEVICES[ \t]*\+=', read(p), re.M)

allfiles = glob.glob(f'{img}/*.mk') + [f'{img}/Makefile']
for p in allfiles:
    if os.path.isfile(p) and 'xiaomi_vince' in read(p):
        print('xiaomi_vince sudah terdaftar di', p); sys.exit(0)

cands = [own] + sorted(glob.glob(f'{img}/*.mk')) + [f'{img}/Makefile']
src = next((p for p in cands if has_dev(p)), None)
if not src:
    print('::error::Tidak ada TARGET_DEVICES di image/*.mk'); sys.exit(2)

own_case = (src == own)

def blk(n):
    return re.compile(r'^define Device/' + re.escape(n) + r'[ \t]*\n.*?^endef[ \t]*\n?', re.M | re.S)

s = read(src)
if own_case:
    s = s.replace(ref, 'msm8953').replace(ref.upper(), 'MSM8953')
names = re.findall(r'^TARGET_DEVICES[ \t]*\+=[ \t]*(\S+)[ \t]*$', s, re.M)
if not names:
    print('::error::Tidak ada device acuan ditemukan'); sys.exit(3)

m = blk(names[0]).search(s)
if not m:
    print('::error::Blok device acuan tidak ditemukan'); sys.exit(4)

new = m.group(0).replace('Device/' + names[0], 'Device/xiaomi_vince')
new = re.sub(r'^([ \t]*DEVICE_VENDOR[ \t]*:?=).*$', r'\1 Xiaomi', new, flags=re.M)
new = re.sub(r'^([ \t]*DEVICE_MODEL[ \t]*:?=).*$', r'\1 Redmi 5 Plus', new, flags=re.M)
new = re.sub(r'^[ \t]*DEVICE_VARIANT[ \t]*:?=.*\n', '', new, flags=re.M)
if re.search(r'^[ \t]*DEVICE_DTS[ \t]*:?=', new, re.M):
    new = re.sub(r'^([ \t]*DEVICE_DTS[ \t]*:?=).*$', r'\1 qcom/msm8953-xiaomi-vince', new, flags=re.M)
else:
    new = re.sub(r'^endef', '  DEVICE_DTS := qcom/msm8953-xiaomi-vince\nendef', new, count=1, flags=re.M)
entry = new.rstrip() + '\nTARGET_DEVICES += xiaomi_vince\n'

if own_case:
    for n in names:
        s = blk(n).sub('', s)
    s = re.sub(r'^TARGET_DEVICES[ \t]*\+=[ \t]*\S+[ \t]*\n?', '', s, flags=re.M)
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(s.rstrip() + '\n\n' + entry)
else:
    tail = re.search(r'^\$\(eval \$\(call BuildImage\)\)[ \t]*$', s, re.M)
    if tail:
        s = s[:tail.start()] + entry + '\n' + s[tail.start():]
    else:
        s = s.rstrip() + '\n\n' + entry
    with open(src, 'w', encoding='utf-8') as f:
        f.write(s)
PY
rc=$?
if [ $rc -ne 0 ]; then exit$rc; fi
echo "Scaffold subtarget & device selesai."
