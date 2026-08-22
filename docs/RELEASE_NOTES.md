# Jetson Nano YOLOv5-OP — Golden Image

A ready-to-flash microSD image for the **Jetson Nano Developer Kit (P3448-0000, 4 GB)** with the full YOLOv5 inference stack pre-built and verified.

## What you get

| | |
|---|---|
| L4T | R32.7.6 (JetPack 4.6.6) |
| OS | Ubuntu 18.04 LTS aarch64, user `jetson` |
| CUDA / cuDNN / TensorRT | 10.2 / 8.2.x / 8.2.x |
| PyTorch | 1.10.0 (NVIDIA aarch64 CUDA build) |
| torchvision | 0.11.x (compiled from source) |
| YOLOv5 | v7.0 + `yolov5n.pt` + **prebuilt `yolov5n.engine`** |

`torch.cuda.is_available()` returns `True` on first boot. The TensorRT engine is already built, so there is no 20-minute wait on first run.

## Assets

The image is 10.25 GiB, above GitHub's 2 GB per-asset limit, so it is split:

```
golden_image.img.gz.part-00 … part-04    1,992,294,400 B each
golden_image.img.gz.part-05              1,045,782,904 B
SHA256SUMS                               verify + reassemble
```

Download and join automatically:

```bash
./scripts/download-image.sh
./scripts/flash.sh
```

Or manually:

```bash
shasum -a 256 -c SHA256SUMS
cat golden_image.img.gz.part-* > golden_image.img.gz
```

## Image facts

| | |
|---|---|
| Compressed | 11,007,254,904 B (10.25 GiB) |
| Raw | 31,138,512,896 B (29.00 GiB) |
| Layout | GPT, 14 partitions |
| Minimum card | 32 GB (64 GB UHS-I U3 recommended) |
| SHA-256 (`.img.gz`) | `85a93cde3f446fcdf16ea73d1d8a6ead68c573f652066172ac6f259badfdf2e3` |

## ⚠️ Read before you put this on a network

This image ships **with SSH host keys baked in**. It was cloned from a working
Jetson without stripping `/etc/ssh/ssh_host_*`, so **every device flashed from
this release shares one SSH identity**. Anyone who downloads the image holds
the private half of your board's host key.

What that means in practice: SSH host-key verification gives you nothing, and
an attacker on your network can impersonate your Nano without triggering a
host-key warning. Fix it on first boot — one command:

```bash
sudo rm -f /etc/ssh/ssh_host_* && sudo ssh-keygen -A && sudo systemctl restart ssh
```

The default password is likewise identical on every clone, and `/etc/shadow`
travels inside the image, so it can be cracked offline. Run `passwd` too.

Verified absent from this image: Wi-Fi passwords, AWS/API tokens, `.netrc`
credentials. Checked with `scripts/scan-image.sh`.

## After flashing

1. Boot with HDMI + keyboard. First boot takes 2–4 min (rootfs expansion).
2. Log in as `jetson`, **change the password**, and **regenerate the SSH host keys** (above).
3. `sudo nvpmodel -m 0 && sudo jetson_clocks`

Full checklist: [docs/FIRST_BOOT.md](../docs/FIRST_BOOT.md)

## Known limitations

- microSD Nano only — will not boot the eMMC module (P3448-0002).
- Not for Orin / Xavier. L4T R32 is Tegra X1 only.
- Do not run `pip install -r yolov5/requirements.txt`; it will break the Python 3.6 environment.

## Licensing

Repo tooling is MIT. The **image** bundles NVIDIA L4T (NVIDIA SLA), Ubuntu, and YOLOv5 (**AGPL-3.0**). Commercial deployment has real obligations — see [LICENSE](../LICENSE).
