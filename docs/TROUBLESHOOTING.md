# Troubleshooting

Symptoms, in the order people actually hit them.

---

## It doesn't boot

**Nothing at all — no LED.**
Power supply. Try a different cable and adapter. The micro-USB port is fussy about cable quality.

**Green LED, black screen, forever.**

| Cause | Check |
|---|---|
| Bad flash | Reinsert the card on your host: `sudo fdisk -l /dev/sdX` must show **14 GPT partitions**. One FAT partition means the write failed. |
| Bad card | Reflash to a different card. If a second card works, the first is dead or fake. |
| Wrong module | This image is for **P3448-0000** (microSD, 4 GB). It will not boot the eMMC P3448-0002. |
| Monitor handshake | Some monitors don't negotiate. Try a different HDMI cable/display, or go serial (below). |

**Read the serial console** — this tells you what's actually happening:

```bash
# On the host, with a 3.3 V USB-TTL adapter on J44:
#   GND → pin 1(GND)   RXD → pin 3(TXD)   TXD → pin 4(RXD)
sudo screen /dev/ttyUSB0 115200      # Linux
screen /dev/tty.usbserial-XXXX 115200   # macOS
```

If you see `Welcome to Minimal BASH-like line editing` or a CBoot prompt, the boot chain loaded but the kernel or rootfs did not — almost always a corrupt write.

**Boots, then reboots in a loop.**
Power. Under-voltage during GPU init causes exactly this. Barrel jack + J48 jumper.

---

## `torch.cuda.is_available()` is `False`

The Nano needs NVIDIA's own aarch64 CUDA build of PyTorch. If anything ran `pip install torch`, it was replaced with a CPU wheel.

```bash
python3 -c "import torch; print(torch.__version__, torch.version.cuda)"
```

`torch.version.cuda` printing `None` confirms it. Restore:

```bash
pip3 uninstall -y torch torchvision
# NVIDIA PyTorch 1.10.0 wheel for JetPack 4.6 / Python 3.6:
wget https://nvidia.box.com/shared/static/fjtbno0vpo676a25cgvuqc1wty0fkkg6.whl -O torch-1.10.0-cp36-cp36m-linux_aarch64.whl
sudo apt install -y libopenblas-base libopenmpi-dev
pip3 install Cython numpy
pip3 install torch-1.10.0-cp36-cp36m-linux_aarch64.whl
```

`torchvision` has no aarch64 wheel — it must be compiled, and that is the ~90 minute step this image exists to spare you:

```bash
sudo apt install -y libjpeg-dev zlib1g-dev libpython3-dev libavcodec-dev libavformat-dev libswscale-dev
git clone --branch v0.11.1 https://github.com/pytorch/vision torchvision
cd torchvision && export BUILD_VERSION=0.11.1
python3 setup.py install --user     # add swap first, or this will be OOM-killed
```

> Rather than repairing a broken environment, reflash. That is the entire point of a golden image.

---

## `pip install -r requirements.txt` breaks everything

Do not run it. YOLOv5's `requirements.txt` pins modern versions that need Python ≥3.8; the Nano is on 3.6. Installing them replaces the working `numpy`, `opencv`, `Pillow`, and `torch`.

Install individual packages only, pinned, and never `torch`/`torchvision`/`opencv`.

---

## `Illegal instruction (core dumped)` on `import numpy`

A known numpy/OpenBLAS interaction on aarch64:

```bash
export OPENBLAS_CORETYPE=ARMV8
echo 'export OPENBLAS_CORETYPE=ARMV8' >> ~/.bashrc
```

---

## Out of memory / the process is killed

4 GB, shared with the GPU. Add swap ([FIRST_BOOT.md §6](FIRST_BOOT.md)), drop to `multi-user.target` to reclaim the desktop's ~400 MB, use `--batch-size 1`, and lower `--img` to 416.

```bash
watch -n1 free -h
sudo jtop        # nicer
```

---

## TensorRT engine won't load

```
[TRT] The engine plan file is not compatible with this version of TensorRT
```

A `.engine` is bound to the exact TensorRT version, GPU, and driver it was built on. The bundled `yolov5n.engine` matches this image; if you upgraded TensorRT or copied an engine from another machine, rebuild it **on the device**:

```bash
cd ~/yolov5
python3 export.py --weights yolov5n.pt --include engine --device 0 --half --imgsz 640
```

Expect 15–30 minutes. It looks frozen. It is not.

---

## Camera not detected

```bash
ls /dev/video*                    # nothing here = kernel doesn't see it
v4l2-ctl --list-devices
dmesg | grep -iE 'imx219|camera|video'
```

**CSI (IMX219 / RPi Cam v2)** — test the hardware path directly, bypassing Python:

```bash
gst-launch-1.0 nvarguscamerasrc ! \
  'video/x-raw(memory:NVMM),width=1280,height=720,framerate=30/1' ! \
  nvvidconv ! nvegltransform ! nveglglessink -e
```

Picture = camera fine, problem is in your code. No picture = check the ribbon cable orientation (contacts toward the heatsink) and that it is fully seated on both ends.

**USB webcam** — `cv2.VideoCapture(0)` failing while `/dev/video0` exists is usually a permissions issue:

```bash
sudo usermod -aG video $USER    # log out and back in
```

**Argus daemon wedged** (common after a crash):

```bash
sudo systemctl restart nvargus-daemon
```

---

## Terrible FPS

Work through these in order:

1. `sudo nvpmodel -m 0 && sudo jetson_clocks` — 5 W mode roughly halves throughput.
2. Use the **TensorRT engine**, not PyTorch. This is the big one.
3. `--img 416` instead of 640.
4. `sudo jtop` → if `GPU` is not near 100%, you are bottlenecked on camera capture or display, not inference.
5. Check thermals — sustained load without a fan throttles hard.

---

## Filesystem went read-only / random corruption

Almost always the SD card, sometimes power. Reflash to a known-good UHS-I U3 card from a real retailer. If you are running 24/7, move the rootfs to a USB SSD.

---

## Still stuck?

Open an issue with:

```bash
cat /etc/nv_tegra_release
nvpmodel -q
free -h
python3 -c "import torch;print(torch.__version__, torch.cuda.is_available())"
dmesg | tail -50
```
