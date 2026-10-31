#!/bin/bash
cd "${1:-openwrt}" || exit 1
LOG="$2"
LOGDIR="$GITHUB_WORKSPACE/ci-logs"; mkdir -p "$LOGDIR"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
PROTECTED_FILE="$LOGDIR/protected.txt"
REPORT="$LOGDIR/auto-fix-report.txt"
: > "$REPORT"
: > "$LOGDIR/auto-disabled.txt"
fixed=0
note() { echo "$1" | tee -a "$REPORT"; }

[ -f "$LOG" ] || { note "[stop] log build tidak ditemukan: $LOG"; exit 1; }

is_protected() { grep -qxF "$1" "$PROTECTED_FILE" 2>/dev/null; }

disable_pkg() {
  local n="$1"
  sed -i "/^CONFIG_PACKAGE_${n}=/d;/^# CONFIG_PACKAGE_${n} is not set/d" .config
  echo "# CONFIG_PACKAGE_${n} is not set" >> .config
  make defconfig > /dev/null 2>&1
  if grep -qE "^CONFIG_PACKAGE_${n}=[ym]" .config; then return 1; fi
  echo "$n" >> "$LOGDIR/auto-disabled.txt"
  return 0
}

if grep -qE 'No space left on device' "$LOG"; then
  note "[stop] Disk penuh: kurangi paket di config."
  df -h . | tee -a "$REPORT"
  { echo '### Auto fix'; echo '```'; cat "$REPORT"; echo '```'; } >> "$SUMMARY"
  exit 1
fi

if grep -qE 'Download failed|Hash check failed|Connection (timed out|reset)|Failed to download|HTTP/[0-9.]+ 403|403 Forbidden|error 403' "$LOG"; then
  note "[fix] download gagal: hapus file korup & retry"
  find dl -type f -size 0 -delete 2>/dev/null
  find dl -name '*.tmp' -delete 2>/dev/null
  make download -j"$(nproc)" WGET="wget --user-agent='Mozilla/5.0'" V=s >> "$LOGDIR/download-retry.log" 2>&1
  fixed=1
fi

if grep -q 'obstack' "$LOG"; then
  n=0
  for f in $(find build_dir/host -path '*elfutils*' -name 'obstack*.h' 2>/dev/null); do
    sed -i 's/#if @HAVE_OBSTACK_PRINTF@/#if 0/g' "$f"; n=$((n+1))
  done
  if [ "$n" -gt 0 ]; then note "[fix] patch obstack elfutils pada $n file"; fixed=1; fi
fi

if grep -qE 'Killed|Out of memory|Cannot allocate memory' "$LOG"; then
  note "[fix] memori kurang: dipaksa ke single-thread mode"
  fixed=1
fi

mapfile -t FAILED < <(grep -oE 'ERROR: [^ ]+ failed to build' "$LOG" | awk '{print $2}' | sort -u)
for path in "${FAILED[@]}"; do
  name=$(basename "$path")
  case "$path" in
    package/feeds/*|package/luci-app-*|package/modemband*) ;;
    *) note "[inti] $path gagal: paket inti tidak dimatikan"; continue ;;
  esac
  if is_protected "$name"; then
    note "[fix] $name (paket wajib) gagal: dibersihkan & rebuild"
    make "$path/clean" > /dev/null 2>&1
    fixed=1
  elif disable_pkg "$name"; then
    note "[fix] $name (opsional) gagal: dinonaktifkan"
    fixed=1
  else
    note "[stop] $name dibutuhkan dependensi lain"
  fi
done

if [ "$fixed" -eq 0 ]; then
  note "[stop] Mengambil detail error..."
  timeout 15m make -j1 V=s 2>&1 | tail -n 200 | cut -c1-300 > "$LOGDIR/detail.log"
  {
    echo '### Auto fix: perbaikan otomatis tidak cocok'
    echo '```'
    grep -nE 'error:|Error [0-9]+|\*\*\* |ERROR:' "$LOGDIR/detail.log" | tail -n 40
    echo '```'
  } >> "$SUMMARY"
  exit 1
fi

{ echo '### Auto fix diterapkan'; echo '```'; cat "$REPORT"; echo '```'; } >> "$SUMMARY"
exit 0
