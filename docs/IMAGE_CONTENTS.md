# What's in the image

Everything below was read directly out of `golden_image.img.gz` unless a row is
marked *(JetPack baseline)*, which means it is the documented content of
JetPack 4.6.6 rather than something inspected byte-for-byte.

---

## Image geometry

| Property | Value |
|---|---|
| Compressed | `11,007,254,904` B (10.25 GiB), gzip |
| Raw | `31,138,512,896` B (29.00 GiB) |
| Sectors | 60,817,408 × 512 B |
| Scheme | GPT (with protective MBR, type `0xEE`) |
| Partitions | 14 |
| Original filename | `golden_image.img` |
| Created | 2026-07-12 11:36:50 UTC |
| SHA-256 | see [`../CHECKSUMS.txt`](../CHECKSUMS.txt) |

## Partitions

| # | Name | Start LBA | Size | Role |
|--:|---|--:|--:|---|
| 1 | `APP` | 28,672 | 28.99 GiB | ext4 rootfs — grows to fill the card on first boot |
| 2 | `TBC` | 2,048 | 128 KiB | TegraBoot CPU |
| 3 | `RP1` | 4,096 | 448 KiB | DRAM training / BCT |
| 4 | `EBT` | 6,144 | 576 KiB | CBoot |
| 5 | `WB0` | 8,192 | 64 KiB | Warm boot (SC7) |
| 6 | `BPF` | 10,240 | 192 KiB | BPMP firmware |
| 7 | `BPF-DTB` | 12,288 | 384 KiB | BPMP device tree |
| 8 | `FX` | 14,336 | 64 KiB | Fuse bypass |
| 9 | `TOS` | 16,384 | 448 KiB | Trusted OS |
| 10 | `DTB` | 18,432 | 448 KiB | Kernel device tree |
| 11 | `LNX` | 20,480 | 768 KiB | Kernel + initrd |
| 12 | `EKS` | 22,528 | 64 KiB | Encrypted key store |
| 13 | `BMP` | 24,576 | 192 KiB | Boot splash |
| 14 | `RP4` | 26,624 | 128 KiB | Secondary boot params |

Partitions 2–14 occupy sectors 2,048–28,671, *before* the rootfs. This is why the image must be written from sector 0 of the device — copying files onto a formatted card produces an unbootable result.

## Platform

| Item | Value | Source |
|---|---|---|
| L4T | `R32 (release), REVISION: 7.6` | `/etc/nv_tegra_release` in the image |
| JetPack | 4.6.6 | maps 1:1 to L4T R32.7.6 |
| Board ID | `3448` (SKU `0000`, FAB `000` and `100`) | board config in the image |
| Module | Jetson Nano 4 GB, microSD (P3448-0000) | from board ID |
| Carrier | A02 (FAB 000) and B01 (FAB 100) both supported | from FAB entries |
| OS | Ubuntu 18.04 LTS `aarch64` | L4T 32.7.x rootfs |
| Default user | `jetson` (home `/home/jetson`) | paths in the image |
| CUDA | 10.2 | *(JetPack baseline)* |
| cuDNN | 8.2.x | *(JetPack baseline)* |
| TensorRT | 8.2.x | *(JetPack baseline)* |
| OpenCV | 4.1.1 | *(JetPack baseline)* |
| Python | 3.6 | Ubuntu 18.04 default |

## ML stack

| Package | Version | Notes |
|---|---|---|
| PyTorch | `1.10.0` | NVIDIA aarch64 CUDA build |
| torchvision | `0.11.x` | compiled from source, tree left at `/home/jetson/torchvision` |
| YOLOv5 | `v7.0` | full Ultralytics checkout |

## YOLOv5 assets found in the image

```
yolov5n.pt              pretrained nano weights
yolov5n.engine          prebuilt TensorRT engine  ← the expensive part, already done
yolov5_trt.py           TensorRT inference script
yolov5_jetson.sh        launcher
models/
  yolov5n.yaml  yolov5s.yaml  yolov5m.yaml  yolov5l.yaml  yolov5x.yaml
  yolov5n6.yaml yolov5s6.yaml yolov5m6.yaml yolov5l6.yaml yolov5x6.yaml
  hub/
    yolov5-fpn.yaml   yolov5-panet.yaml  yolov5-bifpn.yaml
    yolov5-p2.yaml    yolov5-p34.yaml    yolov5-p6.yaml   yolov5-p7.yaml
    yolov5s-ghost.yaml yolov5s-transformer.yaml
```

All YOLOv5 architectures are present, so you can export a larger model on-device if you are willing to wait for the engine build.

## Verifying on the device

Rather than trusting this page, run it yourself after booting:

```bash
cat /etc/nv_tegra_release
nvcc --version
dpkg -l | grep -iE 'cuda|tensorrt|cudnn|opencv' | awk '{print $2, $3}'
python3 -c "import torch, torchvision, cv2; print(torch.__version__, torchvision.__version__, cv2.__version__)"
ls -la ~/yolov5
```

## Privacy note for maintainers

`scripts/shrink-image.sh --prepare` clears shell history, pip and apt caches, logs, and SSH host keys before cloning. Run it every time you cut a release — a golden image otherwise carries whatever was on the source card, including credentials and Wi-Fi PSKs in `/etc/NetworkManager/system-connections/`.
