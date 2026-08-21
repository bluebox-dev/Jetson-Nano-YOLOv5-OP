# Rebuilding this image from scratch

A golden image nobody can reproduce is a black box. This is the path from a
stock NVIDIA SD card image to the artifact published here.

Budget **3–5 hours**, most of it waiting on `torchvision` to compile.

---

## 0. Start clean

Download the official **Jetson Nano Developer Kit SD Card Image** for
**JetPack 4.6.6 / L4T R32.7.6** from
[developer.nvidia.com/embedded/jetpack](https://developer.nvidia.com/embedded/jetpack),
flash it to a 64 GB card, and complete the Ubuntu first-boot wizard with
username **`jetson`**.

## 1. Prepare the system

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip python3-dev libopenblas-base libopenmpi-dev \
                    libjpeg-dev zlib1g-dev libpython3-dev \
                    libavcodec-dev libavformat-dev libswscale-dev \
                    git cmake curl pigz
sudo pip3 install -U pip==21.3.1 setuptools==59.6.0 wheel
```

Pinning pip matters — newer pip drops Python 3.6 support outright.

## 2. Add swap (mandatory)

The torchvision build is OOM-killed on 4 GB without it.

```bash
sudo fallocate -l 6G /var/swapfile
sudo chmod 600 /var/swapfile && sudo mkswap /var/swapfile && sudo swapon /var/swapfile
echo '/var/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
sudo systemctl set-default multi-user.target && sudo reboot   # free the desktop's RAM
```

## 3. PyTorch 1.10.0 — NVIDIA's build, not pip's

```bash
wget https://nvidia.box.com/shared/static/fjtbno0vpo676a25cgvuqc1wty0fkkg6.whl \
     -O torch-1.10.0-cp36-cp36m-linux_aarch64.whl
pip3 install Cython numpy==1.19.4
pip3 install torch-1.10.0-cp36-cp36m-linux_aarch64.whl

python3 -c "import torch; print(torch.__version__, torch.cuda.is_available())"
# 1.10.0 True
```

> Wheel URLs move. The canonical, maintained list is the NVIDIA developer forum
> thread *"PyTorch for Jetson"*. Never `pip install torch` — you get an x86 or
> CPU-only build.

## 4. torchvision 0.11.1 — from source (~90 min)

```bash
cd ~
git clone --branch v0.11.1 https://github.com/pytorch/vision torchvision
cd torchvision
export BUILD_VERSION=0.11.1
export MAX_JOBS=2                    # 4 saturates RAM even with swap
python3 setup.py install --user

cd ~ && python3 -c "import torchvision; print(torchvision.__version__)"
```

The version pairing is not optional: torch 1.10 ↔ torchvision 0.11.x.

## 5. YOLOv5 v7.0

```bash
cd ~
git clone --branch v7.0 https://github.com/ultralytics/yolov5
cd yolov5
```

**Do not run `pip install -r requirements.txt`.** It pins packages that need
Python ≥3.8 and will replace your working torch, numpy, and OpenCV. Install
only what is genuinely missing, pinned:

```bash
pip3 install "matplotlib==3.3.4" "PyYAML==5.4.1" "tqdm==4.64.1" \
             "seaborn==0.11.2" "pandas==1.1.5" "scipy==1.5.4" \
             "requests==2.27.1" "psutil==5.9.5" "thop==0.1.1.post2209072238"
```

OpenCV is already present from JetPack (4.1.1, with CUDA). Leave it alone.

```bash
wget https://github.com/ultralytics/yolov5/releases/download/v7.0/yolov5n.pt
python3 detect.py --weights yolov5n.pt --source data/images --img 640 --device 0
```

## 6. Build the TensorRT engine (~20 min, on-device)

```bash
sudo nvpmodel -m 0 && sudo jetson_clocks
pip3 install "onnx==1.11.0"
python3 export.py --weights yolov5n.pt --include engine --device 0 --half --imgsz 640
```

This produces `yolov5n.engine`. It is bound to this exact GPU + TensorRT +
driver combination, which is precisely why freezing them into an image works.

Add the launcher and TRT inference script (`yolov5_trt.py`,
`yolov5_jetson.sh`) alongside it.

## 7. Sanitise before cloning

```bash
sudo ./scripts/shrink-image.sh --prepare
```

This clears apt/pip caches, logs, shell history, and SSH host keys (installing
a unit that regenerates them on first boot), then zeroes free space so gzip can
actually compress it. Skipping the zeroing step costs several extra gigabytes
in the release; skipping the key removal ships your credentials.

Then shut down and pull the card.

## 8. Clone and compress

```bash
# macOS
sudo dd if=/dev/rdiskN of=golden_image.img bs=4m
# Linux
sudo dd if=/dev/sdX of=golden_image.img bs=4M status=progress

./scripts/shrink-image.sh --compress golden_image.img
```

## 9. Publish

```bash
./scripts/split-image.sh                  # → image-parts/ + SHA256SUMS
./scripts/publish-release.sh v1.0.0
```

Then update the SHA-256 in [`../CHECKSUMS.txt`](../CHECKSUMS.txt) and the
version table in the README.

---

## Why this is worth freezing

| Step | Time | Fails if you get it wrong |
|---|--:|---|
| PyTorch wheel | 10 min | Silently CPU-only |
| torchvision build | 90 min | OOM without swap; version mismatch with torch |
| YOLOv5 deps | 20 min | `requirements.txt` destroys the environment |
| TensorRT engine | 20 min | Not portable between devices/versions |
| Debugging the above | hours | — |

Roughly two evenings, reduced to a 20-minute flash.
