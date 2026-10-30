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
  echo "$n" >> "$LOGDIR/auto-disabled.txt"
  return 0
}

fix_download() {
  find dl -type f -size 0 -delete 2>/dev/null
  find dl -name '*.tmp' -delete 2>/dev/null
  make download -j1 WGET="wget --user-agent='Mozilla/5.0'" V=s >> "$LOGDIR/download-retry.log" 2>&1
  return 0
}

attempt=1
success=0
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "::warning::Waktu habis."; break
  fi
  JOBS=$(nproc)
  if [ "$attempt" -ge 3 ] || [ "$LOW_MEM" -eq 1 ]; then JOBS=1; fi
  LOG="$LOGDIR/attempt-$attempt.log"
  echo "::group::Build attempt $attempt/$MAX_ATTEMPTS (-j$JOBS)"
  make -j"$JOBS" V=s 2>&1 | tee "$LOG" | grep --line-buffered -E '^make\[[0-9]\]: (Entering|\*\*\*)|ERROR:| error:' | cut -c1-200
  rc=${PIPESTATUS[0]}
  echo "::endgroup::"
  if [ "$rc" -eq 0 ]; then success=1; break; fi

  echo "::warning::Attempt $attempt gagal (exit $rc)."
  fixed=0

  if grep -qE 'Download failed|Hash check failed|Connection (timed out|reset)|403' "$LOG"; then
    echo "[fix] ulangi download"; fix_download; fixed=1
  fi

  mapfile -t FAILED < <(grep -oE 'ERROR: [^ ]+ failed to build' "$LOG" | awk '{print $2}' | sort -u)
  for path in "${FAILED[@]}"; do
    name=$(basename "$path")
    if is_protected "$name"; then continue; fi
    FAILCOUNT[$name]=$(( ${FAILCOUNT[$name]:-0} + 1 ))
    if [ "${FAILCOUNT[$name]}" -le 1 ]; then
      make "$path/clean" V=s > /dev/null 2>&1
      fixed=1
    elif disable_pkg "$name"; then
      fixed=1
    fi
  done

  if [ "$fixed" -eq 0 ]; then
    break
  fi
  attempt=$((attempt + 1))
done

if [ "$success" -eq 1 ]; then
  echo "::notice::Build sukses pada percobaan ke-$attempt"
  exit 0
fi
exit 1
