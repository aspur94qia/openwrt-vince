#!/bin/bash
cd "${1:-openwrt}" || exit 1
LOGDIR="$GITHUB_WORKSPACE/ci-logs"; mkdir -p "$LOGDIR"
: > "$LOGDIR/auto-disabled.txt"
PROTECTED_FILE="$LOGDIR/protected.txt"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-8}"
DEADLINE=$(( $(date +%s) + ${BUILD_BUDGET_MIN:-320} * 60 ))
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
declare -A FAILCOUNT
LOW_MEM=0

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

fix_obstack() {
  local n=0 f
  for f in $(find build_dir/host -path '*elfutils*' -name 'obstack*.h' 2>/dev/null); do
    sed -i 's/#if @HAVE_OBSTACK_PRINTF@/#if 0/g' "$f"; n=$((n+1))
  done
  [ "$n" -gt 0 ]
}

fix_download() {
  find dl -type f -size 0 -delete 2>/dev/null
  find dl -name '*.tmp' -delete 2>/dev/null
  make download -j1 WGET="wget --user-agent='Mozilla/5.0'" V=s >> "$LOGDIR/download-retry.log" 2>&1
  return 0
}

summarize_error() {
  {
    echo "### Error terakhir (attempt $attempt)"
    echo '```'
    grep -nE 'error:|Error [0-9]+|\*\*\* |ERROR:' "$1" | tail -n 40 | cut -c1-300
    echo '```'
  } > "$LOGDIR/last-error.txt"
  cat "$LOGDIR/last-error.txt"
  cat "$LOGDIR/last-error.txt" >> "$SUMMARY"
}

attempt=1
success=0
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "::warning::Waktu hampir habis, berhenti mengulang."; break
  fi
  JOBS=$(nproc)
  if [ "$attempt" -ge 3 ] || [ "$LOW_MEM" -eq 1 ]; then JOBS=1; fi
  LOG="$LOGDIR/attempt-$attempt.log"
  echo "::group::Build attempt $attempt/$MAX_ATTEMPTS (-j$JOBS)"
  make -j"$JOBS" V=s 2>&1 | tee "$LOG" | grep --line-buffered -E '^make\[[0-9]\]: (Entering|\*\*\*)|ERROR:| error:' | cut -c1-200
  rc=${PIPESTATUS[0]}
  echo "::endgroup::"
  if [ "$rc" -eq 0 ]; then success=1; break; fi

  echo "::warning::Attempt $attempt gagal (exit $rc). Menganalisis log..."
  fixed=0

  if grep -qE 'No space left on device' "$LOG"; then
    echo "::error::Disk penuh. Kurangi paket di config."
    df -h . | tee -a "$SUMMARY"
    break
  fi
  # Pola 403 dipersempit (angka 403 polos cocok dengan hash/ukuran file di log)
  if grep -qE 'Download failed|Hash check failed|Connection (timed out|reset)|Failed to download|HTTP/[0-9.]+ 403|403 Forbidden|error 403' "$LOG"; then
    echo "[fix] ulangi download"; fix_download; fixed=1
  fi
  if grep -q 'obstack' "$LOG" && fix_obstack; then
    echo "[fix] patch obstack elfutils"; fixed=1
  fi
  if grep -qE 'Killed|Out of memory|Cannot allocate memory' "$LOG"; then
    echo "[fix] memori kurang, build berikutnya -j1"; LOW_MEM=1; fixed=1
  fi

  mapfile -t FAILED < <(grep -oE 'ERROR: [^ ]+ failed to build' "$LOG" | awk '{print $2}' | sort -u)
  for path in "${FAILED[@]}"; do
    name=$(basename "$path")
    case "$path" in
      package/feeds/*|package/luci-app-*|package/modemband*) ;;
      *) echo "[inti] $path gagal: tidak boleh dimatikan otomatis"; continue ;;
    esac
    if is_protected "$name"; then echo "[dilindungi] $name gagal: paket wajib"; continue; fi
    FAILCOUNT[$name]=$(( ${FAILCOUNT[$name]:-0} + 1 ))
    if [ "${FAILCOUNT[$name]}" -le 1 ]; then
      echo "[fix] bersihkan lalu coba lagi: $path"
      make "$path/clean" V=s > /dev/null 2>&1
      fixed=1
    elif disable_pkg "$name"; then
      echo "[fix] nonaktifkan paket yang terus gagal: $name"
      fixed=1
    else
      echo "[stop] $name dipilih ulang oleh dependensi"
    fi
  done

  if [ "$fixed" -eq 0 ]; then
    echo "::error::Tidak ada perbaikan otomatis yang cocok untuk error ini."
    summarize_error "$LOG"
    break
  fi
  attempt=$((attempt + 1))
done

if [ "$success" -eq 1 ]; then
  echo "::notice::Build sukses pada percobaan ke-$attempt"
  {
    echo "### Build sukses (percobaan ke-$attempt)"
    if [ -s "$LOGDIR/auto-disabled.txt" ]; then
      echo "Paket yang dinonaktifkan otomatis:"
      sed 's/^/- /' "$LOGDIR/auto-disabled.txt"
    fi
  } >> "$SUMMARY"
  exit 0
fi
[ -s "$LOGDIR/last-error.txt" ] || summarize_error "$LOG"
exit 1
