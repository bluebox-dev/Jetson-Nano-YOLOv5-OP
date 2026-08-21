#!/usr/bin/env bash
# =============================================================================
#  benchmark.sh — Measure YOLOv5 throughput ON THE JETSON NANO
#
#  Run this on the device (not the host). It records the power mode and clock
#  state alongside the numbers, because Nano FPS is meaningless without them.
#
#  Usage:  ./scripts/benchmark.sh [runs]      (default 3)
#  Output: benchmark-<hostname>-<date>.md — paste it into docs/BENCHMARKS.md
# =============================================================================
set -euo pipefail

RUNS="${1:-3}"
YOLO="${YOLO:-$HOME/yolov5}"
OUT="benchmark-$(hostname)-$(date +%Y%m%d-%H%M).md"

[ -d "$YOLO" ] || { echo "YOLOv5 not found at $YOLO — set YOLO=/path/to/yolov5" >&2; exit 1; }
grep -qi tegra /proc/version 2>/dev/null || echo "WARNING: this does not look like a Jetson. Run it on the device." >&2

{
  echo "## Benchmark — $(hostname), $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
  echo '```'
  echo "L4T        : $(head -1 /etc/nv_tegra_release 2>/dev/null || echo unknown)"
  echo "power mode : $(nvpmodel -q 2>/dev/null | tr '\n' ' ' || echo unknown)"
  echo "clocks     : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo '?') kHz (cpu0)"
  echo "swap       : $(free -m | awk '/Swap/{print $2" MB"}')"
  echo "python     : $(python3 -V 2>&1)"
  python3 - <<'PY' 2>/dev/null || true
import torch, torchvision
print(f"torch      : {torch.__version__}  cuda={torch.cuda.is_available()}")
print(f"torchvision: {torchvision.__version__}")
PY
  echo '```'
  echo
  echo "| Backend | Weights | imgsz | Runs | Mean latency | FPS |"
  echo "|---|---|--:|--:|--:|--:|"
} > "$OUT"

# RECORD=0 -> warm-up only, nothing written to the report
bench_pytorch() {
  local w="$1" sz="$2" record="${3:-1}"
  [ -f "$YOLO/$w" ] || { echo "  skip: $w missing"; return; }
  echo "==> PyTorch $w @ ${sz}px"
  local log
  log=$(cd "$YOLO" && python3 detect.py --weights "$w" --source data/images \
        --img "$sz" --device 0 --nosave 2>&1 | tail -40)
  local ms
  ms=$(echo "$log" | grep -oE '[0-9.]+ms inference' | grep -oE '^[0-9.]+' \
       | awk '{s+=$1; n++} END{if(n) printf "%.1f", s/n}')
  [ -n "$ms" ] || { echo "  no timing parsed"; return; }
  local fps; fps=$(awk -v m="$ms" 'BEGIN{printf "%.1f", 1000/m}')
  [ "$record" = 1 ] && echo "| PyTorch | \`$w\` | $sz | $RUNS | ${ms} ms | ${fps} |" >> "$OUT"
  echo "  ${ms} ms  →  ${fps} FPS"
}

bench_trt() {
  local e="$1" sz="$2"
  [ -f "$YOLO/$e" ] || { echo "  skip: $e missing"; return; }
  echo "==> TensorRT $e @ ${sz}px"
  if command -v /usr/src/tensorrt/bin/trtexec >/dev/null; then
    local log ms
    log=$(/usr/src/tensorrt/bin/trtexec --loadEngine="$YOLO/$e" --iterations=100 --avgRuns=10 2>&1 | tail -30)
    ms=$(echo "$log" | grep -oE 'mean = [0-9.]+ ms' | grep -oE '[0-9.]+' | head -1)
    if [ -n "$ms" ]; then
      local fps; fps=$(awk -v m="$ms" 'BEGIN{printf "%.1f", 1000/m}')
      echo "| TensorRT | \`$e\` | $sz | 100 | ${ms} ms | ${fps} |" >> "$OUT"
      echo "  ${ms} ms  →  ${fps} FPS"
    fi
  else
    echo "  trtexec not found at /usr/src/tensorrt/bin/trtexec"
  fi
}

# Warm up: first run pays for cuDNN autotuning and page cache, and would
# otherwise dominate the average.
for _ in $(seq 1 "$RUNS"); do
  echo "--- warm-up ---"
  bench_pytorch yolov5n.pt 640 0 >/dev/null 2>&1 || true
done
bench_pytorch yolov5n.pt 640
bench_pytorch yolov5n.pt 416
bench_trt     yolov5n.engine 640

{
  echo
  echo "> Measured with \`scripts/benchmark.sh\`. Numbers are inference-only and"
  echo "> exclude camera capture and rendering."
} >> "$OUT"

echo
echo "==> Wrote $OUT"
echo "    Open a PR adding it to docs/BENCHMARKS.md."
