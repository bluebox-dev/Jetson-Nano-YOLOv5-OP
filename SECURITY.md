# Security

## Golden images and shared secrets

Every device flashed from this image starts identical. That means:

- **The default password is not a secret.** Anyone with the image knows it. Run `passwd` before connecting the device to any network.
- **Check your SSH host keys.** `scripts/shrink-image.sh --prepare` strips them and installs a `regen-ssh-hostkeys` unit that recreates them on first boot, so clones do not share a host identity. If your image was not prepared that way, regenerate them yourself:

  ```bash
  sudo rm -f /etc/ssh/ssh_host_* && sudo ssh-keygen -A && sudo systemctl restart ssh
  ```
- **This image is not hardened.** Ubuntu 18.04 reached end of standard support in April 2023. JetPack 4.6.6 is the last release for Jetson Nano, so kernel and userspace CVEs will not be patched upstream. Treat any Nano running this image as an untrusted-network device: put it behind a firewall, do not expose SSH to the internet, and do not store credentials on it.

## Reporting a problem with a published image

If you find credentials, API keys, Wi-Fi PSKs, personal data, or anything else
that should not have shipped inside a released image, please **do not open a
public issue**. Use GitHub's private vulnerability reporting on this repository
so the release can be withdrawn before the details are public.

For vulnerabilities in the upstream components — L4T, Ubuntu packages, PyTorch,
YOLOv5 — report them to those projects; this repository only packages them.

## Verifying what you downloaded

Always check the image against the published hash before flashing:

```bash
./scripts/verify.sh golden_image.img.gz
```

The expected value is in [CHECKSUMS.txt](CHECKSUMS.txt) and on the release page.
A mismatch means a corrupt download or a tampered file — do not flash it.
