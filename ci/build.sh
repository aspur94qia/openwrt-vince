#!/bin/bash
cd "${1:-openwrt}" || exit 1
LOGDIR="$GITHUB_WORKSPACE/ci-logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/build.log"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

JOBS=$(nproc)
echo "Starting 1-Pass High Speed Build using $JOBS threads..."

make -j"$JOBS" 2>&1 | tee "$LOG" | grep --line-buffered -E '^make\[[0-9]\]: (Entering|\*\*\*)|ERROR:| error:' | cut -c1-200
rc=${PIPESTATUS[0]}

if [ "$rc" -ne 0 ]; then
  {
    echo "### Build Firmware Gagal (Exit Code $rc)"
    echo '```'
    grep -nE 'error:|Error [0-9]+|\*\*\* |ERROR:' "$LOG" | tail -n 40 | cut -c1-300
    echo '```'
  } >> "$SUMMARY"
fi
exit "$rc"
