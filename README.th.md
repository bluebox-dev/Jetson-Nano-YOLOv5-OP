<div align="center">

<img src="assets/banner.svg" alt="Jetson Nano YOLOv5-OP Golden Image" width="100%">

# Jetson Nano · YOLOv5 · Golden Image

**ไฟล์ image สำเร็จรูปสำหรับ flash ลง microSD — เปลี่ยน Jetson Nano เปล่า ๆ ให้รัน YOLOv5 ได้ภายใน 20 นาที แทนที่จะนั่งแก้ dependency สองวัน**

[![Platform](https://img.shields.io/badge/platform-Jetson%20Nano%20(P3448)-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://developer.nvidia.com/embedded/jetson-nano)
[![JetPack](https://img.shields.io/badge/JetPack-4.6.6-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://developer.nvidia.com/embedded/jetpack)
[![L4T](https://img.shields.io/badge/L4T-R32.7.6-76B900?style=for-the-badge)](https://developer.nvidia.com/embedded/linux-tegra)
[![YOLOv5](https://img.shields.io/badge/YOLOv5-v7.0-00FFFF?style=for-the-badge)](https://github.com/ultralytics/yolov5)
[![PyTorch](https://img.shields.io/badge/PyTorch-1.10.0-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)](https://pytorch.org)

<samp>29 GiB ดิบ &nbsp;•&nbsp; 10.25 GiB บีบอัด &nbsp;•&nbsp; ต้องใช้ microSD อย่างน้อย 32 GB</samp>

[**English**](README.md) &nbsp;·&nbsp; [**เริ่มใช้งาน**](#th-quickstart) &nbsp;·&nbsp; [**มีอะไรอยู่ข้างใน**](#th-contents) &nbsp;·&nbsp; [**แก้ปัญหา**](docs/TROUBLESHOOTING.md) &nbsp;·&nbsp; [**คำถามที่พบบ่อย**](docs/FAQ_TH.md)

</div>

---

## 🧨 ปัญหาที่ image นี้แก้ให้

การทำให้ YOLOv5 รันบน Jetson Nano นั้นทรมานเป็นที่เลื่องลือ เพราะ Nano ติดอยู่ที่ **JetPack 4.6.x / Ubuntu 18.04 / Python 3.6 / CUDA 10.2** ซึ่งหมายความว่า:

| กับดัก | สิ่งที่เกิดขึ้นจริง |
|---|---|
| `pip install torch` | ได้ wheel ของ x86 หรือ CPU-only — ใช้ CUDA ไม่ได้ |
| `pip install torchvision` | ไม่มี wheel สำหรับ aarch64 ต้อง compile เอง ~90 นาที และ OOM ถ้าไม่เพิ่ม swap |
| `pip install -r yolov5/requirements.txt` | ดึง numpy/opencv/Pillow เวอร์ชันที่ต้องใช้ Python ≥3.8 → พังทันที |
| compile อะไรก็ตาม | RAM แค่ 4 GB — `gcc` โดน OOM kill กลางทาง |
| อยากได้ FPS จริงจัง | PyTorch เพียว ๆ ได้ FPS หลักหน่วย ต้องสร้าง TensorRT engine บนเครื่องเอง |

**image นี้คือสงครามทั้งหมดนั้นที่ชนะแล้วและถูกแช่แข็งไว้** — บูตขึ้นมา `torch.cuda.is_available()` คืนค่า `True` ตั้งแต่ครั้งแรก

---

<a id="th-contents"></a>

## 📦 มีอะไรอยู่ข้างใน

| ชั้น | เวอร์ชัน | หมายเหตุ |
|---|---|---|
| **L4T** | `R32.7.6` | ตรวจจาก `/etc/nv_tegra_release` ใน image จริง |
| **JetPack** | `4.6.6` | รุ่นสุดท้ายที่รองรับ Jetson Nano |
| **OS** | Ubuntu 18.04 LTS `aarch64` | ผู้ใช้เริ่มต้น `jetson` |
| **CUDA** | `10.2` | มาตรฐานของ JetPack 4.6.6 |
| **cuDNN / TensorRT** | `8.2.x` | มาตรฐานของ JetPack 4.6.6 |
| **PyTorch** | `1.10.0` | build จาก NVIDIA สำหรับ aarch64 + CUDA (ไม่ใช่ pip wheel) |
| **torchvision** | `0.11.x` | compile จาก source บนเครื่อง (`/home/jetson/torchvision`) |
| **YOLOv5** | `v7.0` | โค้ดครบทั้ง repo พร้อม model YAML ทุกตัว |
| **น้ำหนักโมเดล** | `yolov5n.pt` | ขนาดเหมาะกับ RAM 4 GB / 128 CUDA cores |
| **TensorRT engine** | `yolov5n.engine` | **สร้างไว้ให้แล้ว** — ข้ามขั้นตอนที่ช้าที่สุด |
| **สคริปต์ช่วย** | `yolov5_trt.py`, `yolov5_jetson.sh` | inference ผ่าน TensorRT + ตัวเรียกใช้ |

> [!NOTE]
> ไฟล์ `.engine` ของ TensorRT ผูกกับ GPU, เวอร์ชัน TensorRT และ driver ที่ใช้สร้างพอดีเป๊ะ เนื่องจาก image นี้แช่แข็งทั้งสามอย่างไว้ `yolov5n.engine` จึงโหลดได้ทันทีบน Jetson Nano ทุกเครื่อง ไม่ต้องรอ build ใหม่ 20 นาที

---

<a id="th-quickstart"></a>

## 🚀 เริ่มใช้งานอย่างเร็ว

```bash
git clone https://github.com/bluebox-dev/Jetson-Nano-YOLOv5-OP.git
cd Jetson-Nano-YOLOv5-OP

./scripts/download-image.sh     # 1. ดาวน์โหลด + ตรวจสอบ ~10 GB จาก Releases
./scripts/flash.sh              # 2. เลือก SD card แล้วพิมพ์ ERASE
                                # 3. เสียบการ์ดใส่ Nano แล้วเปิดเครื่อง — จบ
```

---

## 🖥️ สิ่งที่ต้องเตรียม

| | ขั้นต่ำ | แนะนำ |
|---|---|---|
| **บอร์ด** | Jetson Nano Dev Kit โมดูล **P3448-0000** (4 GB, microSD) | เหมือนกัน + carrier **B01** |
| **microSD** | 32 GB UHS-I | **64 GB UHS-I U3 / A2** — SanDisk Extreme หรือ Samsung EVO Select |
| **ไฟเลี้ยง** | micro-USB 5V 2A | **barrel jack 5V 4A + ใส่ jumper J48** (จำเป็นสำหรับโหมด MAXN) |
| **พื้นที่ดิสก์บนเครื่อง host** | ~21 GB | 40 GB |

> [!WARNING]
> image นี้ใช้กับ Jetson Nano รุ่น **microSD** (P3448-**0000**) เท่านั้น รุ่น eMMC 16 GB (P3448-0002) บูตไม่ได้ ต้อง flash ผ่าน USB recovery mode ด้วย L4T BSP แทน

> [!CAUTION]
> SD card ปลอมหรือของถูกเกินจริงคือสาเหตุอันดับหนึ่งของอาการ "บูตได้ครั้งเดียวแล้วไฟล์พัง" ซื้อจากร้านที่เชื่อถือได้

> [!CAUTION]
> **image นี้มี SSH host key ติดมาด้วย — ทุกเครื่องที่ flash จะมี SSH identity เดียวกัน และ private key เป็นสาธารณะ** ต้อง regenerate ก่อนต่อเน็ตเสมอ:
> ```bash
> sudo rm -f /etc/ssh/ssh_host_* && sudo ssh-keygen -A && sudo systemctl restart ssh
> ```
> รหัสผ่านเริ่มต้นก็เหมือนกันทุกเครื่อง อย่าลืม `passwd` ดูรายละเอียดที่ [SECURITY.md](SECURITY.md)

---

## 📥 ดาวน์โหลด image

image ขนาด 10.25 GiB จึงเผยแพร่ผ่าน **GitHub Release assets** ไม่ได้ commit ลง git

<details>
<summary><b>ทำไมไม่เก็บ <code>.img.gz</code> ไว้ใน repo?</b> (คลิก)</summary>

<br>

GitHub มีเพดานที่ไฟล์นี้ทะลุไปหมด:

| ช่องทาง | เพดานต่อไฟล์ | ผลกับ image 10.25 GiB |
|---|---|---|
| git push ปกติ | **100 MB** (บล็อกตายตัว) | ❌ push ไม่ผ่าน |
| Git LFS | **2 GB** ต่อไฟล์, ฟรี 1 GB | ❌ ใหญ่เกิน และต้องเสียเงิน |
| **GitHub Releases** | **2 GB ต่อ asset** ไม่จำกัดจำนวน ฟรี | ✅ **แบ่งเป็น 6 ส่วน** |

`split-image.sh` จึงตัด image เป็นชิ้นละ 1900 MB พร้อมไฟล์ `SHA256SUMS`, `publish-release.sh` อัปโหลดขึ้น release, และ `download-image.sh` ดึงกลับมา ตรวจ checksum ทุกชิ้น แล้วต่อกลับเป็นไฟล์เดิมแบบ byte-for-byte

</details>

```bash
./scripts/download-image.sh     # ต้องมี GitHub CLI (gh)
```

หรือดาวน์โหลดเองจากหน้า [Releases](https://github.com/bluebox-dev/Jetson-Nano-YOLOv5-OP/releases/latest) ทุกไฟล์ `golden_image.img.gz.part-*` และ `SHA256SUMS` แล้ว:

```bash
cd image-parts && shasum -a 256 -c SHA256SUMS && cat golden_image.img.gz.part-* > ../golden_image.img.gz
```

### ตรวจสอบความถูกต้อง

| รายการ | ค่า |
|---|---|
| ขนาดบีบอัด | `11,007,254,904` bytes (10.25 GiB) |
| ขนาดดิบ | `31,138,512,896` bytes (29.00 GiB, 60,817,408 × 512 B) |
| อัตราบีบอัด | 35.4% ของต้นฉบับ |
| SHA-256 | ดู [`CHECKSUMS.txt`](CHECKSUMS.txt) |

---

## 🔥 flash ลงการ์ด

### macOS / Linux

```bash
./scripts/flash.sh
```

สคริปต์จะแสดงเฉพาะอุปกรณ์ที่ถอดได้, ปฏิเสธการเขียนทับดิสก์ระบบ, ตรวจว่าการ์ด ≥32 GB, บังคับให้พิมพ์ `ERASE`, unmount, แล้วสตรีม `gunzip → dd` (ใช้ `pigz`/`pv` ถ้ามี) ใช้เวลา **15–45 นาที**

<details>
<summary><b>ทำเองด้วยมือ</b></summary>

<br>

**macOS** — สังเกตว่าใช้ `rdisk` ซึ่งเร็วกว่า `disk` ประมาณ 10 เท่า:

```bash
diskutil list external physical
diskutil unmountDisk /dev/diskN
gzip -dc golden_image.img.gz | sudo dd of=/dev/rdiskN bs=4m
sync && diskutil eject /dev/diskN
```

**Linux:**

```bash
lsblk -dpo NAME,SIZE,TYPE,RM,MODEL
sudo umount /dev/sdX?*
gzip -dc golden_image.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync && sudo eject /dev/sdX
```

ใส่ `N` / `X` ผิด = ล้างดิสก์ผิดตัว และกู้คืนไม่ได้

</details>

### Windows

ใช้ **[Balena Etcher](https://etcher.balena.io/)** — อ่าน `.img.gz` ได้ตรง ๆ ตรวจสอบหลังเขียนให้ และไม่แสดงไดรฟ์ระบบให้เลือกผิด หรือจะใช้ [Raspberry Pi Imager](https://www.raspberrypi.com/software/) เลือก "Use custom" ก็ได้

> หลัง flash เสร็จ Windows/macOS จะถามว่าจะ format การ์ดไหม — **กด Cancel / Ignore** การ์ดไม่ได้เสีย แต่ระบบอ่าน ext4 ไม่ออก

---

## ⚡ บูตครั้งแรก

1. เสียบการ์ด ต่อ **HDMI + คีย์บอร์ด + เมาส์** แล้วจ่ายไฟ
2. ไฟ LED สีเขียวติด และเห็นโลโก้ NVIDIA ภายใน ~10 วินาที **บูตครั้งแรกใช้เวลา 2–4 นาที** ระหว่างขยาย rootfs — อย่าถอดไฟ
3. ล็อกอินด้วยผู้ใช้ **`jetson`**
4. ทำสิ่งเหล่านี้ทันที:

```bash
passwd                    # เปลี่ยนรหัสผ่าน — สำคัญมาก ทุกเครื่องที่ flash จาก image เดียวกันรหัสเหมือนกันหมด
sudo nvpmodel -m 0        # โหมด MAXN: 4 cores + คล็อกสูงสุด (ต้องใช้ไฟ barrel jack)
sudo jetson_clocks        # ล็อกคล็อกไว้ที่สูงสุด
```

รายการทั้งหมด รวมถึง swap, พัดลม และการใช้งานแบบ headless อยู่ที่ **[docs/FIRST_BOOT.md](docs/FIRST_BOOT.md)**

---

## 🎯 รัน YOLOv5

### เช็คว่าทุกอย่างพร้อม

```bash
python3 -c "import torch, torchvision; print(torch.__version__, torchvision.__version__, torch.cuda.is_available())"
# ควรได้: 1.10.0 0.11.x True
```

### รันด้วย PyTorch

```bash
cd ~/yolov5
python3 detect.py --weights yolov5n.pt --source data/images --img 640 --device 0
```

### รันด้วย TensorRT — ทางที่เร็ว

```bash
python3 yolov5_trt.py --engine yolov5n.engine --source 0    # /dev/video0
# หรือ
./yolov5_jetson.sh
```

### กล้อง CSI (IMX219 / Raspberry Pi Camera v2)

```bash
gst-launch-1.0 nvarguscamerasrc ! \
  'video/x-raw(memory:NVMM),width=1280,height=720,framerate=30/1' ! \
  nvvidconv ! nvegltransform ! nveglglessink -e
```

ถ้าเห็นภาพ แปลว่ากล้องปกติ ปัญหาอยู่ที่โค้ด Python

### วัดความเร็วเอง

ตัวเลข FPS ของ Nano แกว่งมากตามโหมดไฟ ความละเอียด และ pipeline ของกล้อง repo นี้จึงให้เครื่องมือวัดแทนที่จะให้ตัวเลขโฆษณา:

```bash
./scripts/benchmark.sh      # รันบน Nano
```

**ยินดีรับ PR เพิ่มผลของคุณลงใน [docs/BENCHMARKS.md](docs/BENCHMARKS.md)**

---

## 🗂️ โครงสร้าง repo

```
Jetson-Nano-YOLOv5-OP/
├── README.md / README.th.md
├── CHECKSUMS.txt              ← SHA-256 ของ image ที่เผยแพร่
├── scripts/
│   ├── flash.sh               ← เขียน image ลงการ์ด (ปลอดภัย, ถามยืนยัน)
│   ├── scan-image.sh          ← สแกนหา credential ก่อนเผยแพร่ (บังคับ)
│   ├── download-image.sh      ← ดาวน์โหลด + ตรวจสอบ + ต่อไฟล์
│   ├── verify.sh              ← ตรวจ checksum
│   ├── split-image.sh         ← (ผู้ดูแล) ตัด image เป็น release assets
│   ├── publish-release.sh     ← (ผู้ดูแล) อัปโหลดขึ้น GitHub Release
│   ├── benchmark.sh           ← วัด FPS/latency บนเครื่อง
│   └── shrink-image.sh        ← (ผู้ดูแล) ล้างข้อมูล + zero free space ก่อนบีบอัด
└── docs/
    ├── FLASHING.md            ← วิธี flash ทุก OS แบบละเอียด
    ├── FIRST_BOOT.md          ← เช็คลิสต์หลัง flash
    ├── IMAGE_CONTENTS.md      ← มีอะไรติดตั้งไว้บ้าง อยู่ตรงไหน
    ├── BUILD_FROM_SCRATCH.md  ← สร้าง image นี้ใหม่เองทีละขั้น
    ├── BENCHMARKS.md          ← ผลวัดจากชุมชน
    ├── TROUBLESHOOTING.md     ← บูตไม่ขึ้น / ไม่มี CUDA / กล้องไม่ทำงาน
    └── FAQ_TH.md              ← คำถามที่พบบ่อย
```

---

## 📄 สัญญาอนุญาต

**สคริปต์และเอกสารใน repo นี้** ใช้สัญญาอนุญาต MIT — ดู [LICENSE](LICENSE)

**ตัวไฟล์ image ไม่ใช่** เพราะเป็นงานประกอบที่มี NVIDIA L4T / JetPack (NVIDIA SLA), Ubuntu 18.04 และ Ultralytics YOLOv5 (**AGPL-3.0**) รวมอยู่ การนำไปแจกจ่ายต่อหรือใช้ในเชิงพาณิชย์ต้องปฏิบัติตามสัญญาอนุญาตของแต่ละส่วน โดยเฉพาะ AGPL-3.0 ของ YOLOv5 ที่มีข้อผูกพันเรื่องการเปิดเผยซอร์สโค้ดหากนำไปให้บริการผ่านเครือข่าย

<div align="center"><br><sub>⭐ ถ้า repo นี้ช่วยประหยัดเวลาคุณไปหนึ่งสุดสัปดาห์ ฝากกดดาวด้วยครับ</sub></div>
