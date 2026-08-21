# Flashing guide

Everything you need to get `golden_image.img.gz` onto a microSD card, per host OS.

> **Raw size:** 31,138,512,896 bytes (29.00 GiB) · **Minimum card:** 32 GB · **Recommended:** 64 GB UHS-I U3/A2

---

## Before you start

1. **Verify the download.** A truncated image flashes happily and then fails to boot.
   ```bash
   ./scripts/verify.sh golden_image.img.gz
   ```
2. **Use a real card.** Counterfeit and worn-out cards are the most common cause of "boots once, then corrupts." On Linux, `f3probe` will tell you the truth about a card's actual capacity.
3. **Know your device node.** Writing to the wrong one destroys that disk with no recovery.

---

## macOS

The repo script handles all of this, including using `rdisk` (raw device, ~10× faster):

```bash
./scripts/flash.sh
```

Manually:

```bash
# 1. Identify the card — external physical devices only
diskutil list external physical

# 2. Unmount (but do NOT eject) — replace N
diskutil unmountDisk /dev/diskN

# 3. Write. rdisk, not disk. bs=4m lowercase on macOS.
gzip -dc golden_image.img.gz | sudo dd of=/dev/rdiskN bs=4m

# 4. Flush and eject
sync
diskutil eject /dev/diskN
```

**Progress:** press <kbd>Ctrl</kbd>+<kbd>T</kbd> during `dd` to print a status line. Or install `pv`:

```bash
brew install pv pigz
pigz -dc golden_image.img.gz | pv -s 31138512896 | sudo dd of=/dev/rdiskN bs=4m
```

**macOS will pop up "The disk you inserted was not readable."** That's expected — macOS cannot read ext4 or the Tegra partitions. Click **Ignore**, never **Initialize**.

---

## Linux

```bash
./scripts/flash.sh
```

Manually:

```bash
# 1. Identify — RM=1 means removable
lsblk -dpo NAME,SIZE,TYPE,RM,MODEL

# 2. Unmount every partition on it
sudo umount /dev/sdX?* 2>/dev/null

# 3. Write. bs=4M uppercase on Linux. conv=fsync makes dd honest about completion.
gzip -dc golden_image.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync

# 4. Flush
sync && sudo eject /dev/sdX
```

Faster, with all cores:

```bash
sudo apt install pigz pv
pigz -dc golden_image.img.gz | pv -s 31138512896 | sudo dd of=/dev/sdX bs=4M conv=fsync
```

> If your card reader appears as `/dev/mmcblk0`, its partitions are `/dev/mmcblk0p1` etc. Write to the **whole device** (`/dev/mmcblk0`), never a partition.

---

## Windows

Use a GUI tool — raw `dd` on Windows is more trouble than it is worth.

### Balena Etcher (recommended)

1. Install [Etcher](https://etcher.balena.io/).
2. **Flash from file** → `golden_image.img.gz` (Etcher decompresses gzip for you).
3. **Select target** → your SD card. Etcher hides system drives by default.
4. **Flash!** — then let the verification pass finish.
5. Windows will offer to format the card afterwards. **Cancel.** The card is fine; Windows just can't read ext4.

### Raspberry Pi Imager

Works fine despite the name: **Choose OS → Use custom → `golden_image.img.gz`**, choose the card, write. Skip the OS-customisation prompt — those settings are Raspberry Pi OS specific and do nothing here.

### Win32 Disk Imager

Requires you to `gunzip` to a plain `.img` first (needs ~29 GB free), then write that.

---

## How long should it take?

| Card class | Realistic write time |
|---|---|
| UHS-I U1 (Class 10) | 40–60 min |
| UHS-I U3 / A2 | 15–25 min |
| Cheap no-name card | 60+ min, if it survives |

The bottleneck is the card, not gzip. If it's taking two hours, the card is the problem.

---

## Verify the flash actually worked

Reinsert the card and check the partition table is there:

```bash
# macOS
diskutil list /dev/diskN          # expect a 29 GB "Linux" / unrecognised scheme

# Linux
sudo fdisk -l /dev/sdX            # expect 14 GPT partitions, APP being the big one
```

Seeing exactly one small FAT partition means the write did not take — the tool wrote only part of the image, or wrote to a partition instead of the device.

---

## Next

→ [FIRST_BOOT.md](FIRST_BOOT.md)
