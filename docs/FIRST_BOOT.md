# First boot checklist

## 1. Wire it up

| Port | What to connect |
|---|---|
| **microSD** | The card you just flashed (slot is under the module) |
| **HDMI / DP** | A monitor — needed for the very first login |
| **USB** | Keyboard + mouse |
| **Power** | 5 V 2 A micro-USB, **or** 5 V 4 A barrel jack with the **J48 jumper fitted** |

> [!IMPORTANT]
> Micro-USB power cannot sustain MAXN mode. If the board reboots or hard-locks the moment inference starts, it is the power supply — every time. Use the barrel jack with J48 jumpered.

## 2. Boot

- Green power LED lights immediately.
- NVIDIA splash within ~10 seconds.
- **First boot takes 2–4 minutes** while the root filesystem expands to fill the card. Do not power-cycle during this.
- Login user: **`jetson`**

If the screen stays black past 60 seconds, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#it-doesnt-boot).

## 3. Secure it — do this before touching a network

```bash
passwd                                   # change the default password. Not optional.
sudo hostnamectl set-hostname my-nano    # unique hostname if you'll run several
```

Every clone of this image starts with the same credentials. Treat a freshly flashed Nano as untrusted until you have changed the password.

Check whether SSH host keys are unique to your board — if the image was cut with `scripts/shrink-image.sh --prepare`, they are regenerated on first boot; otherwise every clone shares one identity:

```bash
systemctl status regen-ssh-hostkeys 2>/dev/null
sudo ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub
# not unique? regenerate:  sudo rm /etc/ssh/ssh_host_* && sudo ssh-keygen -A && sudo systemctl restart ssh
```

## 4. Set performance mode

```bash
sudo nvpmodel -m 0        # 0 = MAXN: 4 cores, max GPU clock (needs barrel-jack power)
sudo jetson_clocks        # pin clocks to max — no dynamic scaling
nvpmodel -q               # confirm
```

Make it survive reboot:

```bash
sudo systemctl enable --now nvpmodel
echo '@reboot root /usr/bin/jetson_clocks' | sudo tee /etc/cron.d/jetson-clocks
```

`nvpmodel -m 1` is 5 W mode: two cores, low clocks. Useful on USB power, roughly halves your FPS.

## 5. Check the stack

```bash
cat /etc/nv_tegra_release
# expect: # R32 (release), REVISION: 7.6 ...

python3 -c "import torch, torchvision; print(torch.__version__, torchvision.__version__, torch.cuda.is_available())"
# expect: 1.10.0 0.11.x True

nvcc --version            # CUDA 10.2
dpkg -l | grep -i tensorrt | head
```

`torch.cuda.is_available()` returning `False` means something replaced the NVIDIA build of PyTorch. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#torchcudais_available-is-false).

## 6. Swap

The Nano has 4 GB shared between CPU and GPU. Anything that compiles, or a large batch, will OOM without swap.

```bash
free -h                                     # check what's already configured
sudo fallocate -l 4G /var/swapfile
sudo chmod 600 /var/swapfile
sudo mkswap /var/swapfile
sudo swapon /var/swapfile
echo '/var/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

Put swap on a USB SSD if you have one — swapping to the SD card is slow and wears it out.

## 7. Cooling

The Nano thermal-throttles hard under sustained inference. If you have the 5 V fan on the heatsink:

```bash
sudo sh -c 'echo 200 > /sys/devices/pwm-fan/target_pwm'    # 0–255, takes effect instantly
sudo apt install python3-pip && sudo pip3 install jetson-stats
sudo jtop                                                   # live temps, clocks, power
```

Passive cooling is fine for a demo, not for a camera running all day.

## 8. Headless operation

```bash
sudo systemctl set-default multi-user.target   # no desktop → frees ~400 MB RAM
sudo systemctl enable ssh
ip addr show                                   # note the address, then unplug HDMI
```

Back to desktop: `sudo systemctl set-default graphical.target`

## 9. Go detect something

→ [Run YOLOv5](../README.md#-run-yolov5)
