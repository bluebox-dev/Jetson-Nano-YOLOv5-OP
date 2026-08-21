# Benchmarks

Jetson Nano throughput depends heavily on power mode, clocks, thermals, input
resolution, and whether the capture/display pipeline is included. Published
figures on the internet are mostly incomparable for that reason.

**This page contains only measured results, with their conditions recorded.**
It starts empty on purpose — no numbers invented here.

## Contribute yours

On the device:

```bash
./scripts/benchmark.sh
```

It writes `benchmark-<hostname>-<date>.md` including L4T version, power mode,
clock state, and swap. Paste that block into the table below and open a PR.

## Results

| Backend | Model | imgsz | Power mode | Clocks | Latency | FPS | Contributor |
|---|---|--:|---|---|--:|--:|---|
| _(no results yet — be the first)_ | | | | | | | |

## Reading the numbers fairly

- **Inference-only vs end-to-end.** `detect.py` prints inference time; a live camera pipeline adds capture, colour conversion, NMS, and rendering. End-to-end FPS is always lower.
- **MAXN vs 5 W.** `nvpmodel -m 1` roughly halves throughput. Always state the mode.
- **Thermals.** A passively-cooled Nano throttles after a few minutes of sustained load. A 30-second benchmark flatters the hardware.
- **First run is slow.** cuDNN autotuning and TensorRT deserialisation happen once. Warm up before measuring — `benchmark.sh` does.
