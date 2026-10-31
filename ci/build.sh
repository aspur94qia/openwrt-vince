#!/bin/bash
cd "${1:-openwrt}" || exit 1
PASS="${2:-1}"
LOGDIR="$GITHUB_WORKSPACE/ci-logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/build-$PASS.log"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ "$PASS" = "1" ]; then 
  ARGS=(-j"$(nproc)")
else 
  ARGS=(-j1 V=s)
fi

echo "Build pass $PASS: make ${ARGS[*]}"
make "${ARGS[@]}" 2>&1 | tee "$LOG" | grep --line-buffered -E '^make\[[0-9]\]: (Entering|\*\*\*)|ERROR:| error:' | cut -c1-200
rc=${PIPESTATUS[0]}

if [ "$rc" -ne 0 ]; then
  {
    echo "### Build pass $PASS gagal (exit $rc)"
    echo '```'
    grep -nE 'error:|Error [0-9]+|\*\*\* |ERROR:' "$LOG" | tail -n 30 | cut -c1-300
    echo '```'
  } >> "$SUMMARY"
fi
exit "$rc"
