#!/usr/bin/env bash
# =============================================================================
#  shrink-image.sh — Maintainer tool: make the golden image compress well
#
#  Free space on a used filesystem is full of deleted-file garbage, which gzip
#  faithfully preserves. Zeroing it first can cut gigabytes off the release.
#
#  STEP 1 — on the Jetson, before you clone the card:
#      sudo ./scripts/shrink-image.sh --prepare
#
#  STEP 2 — on the host, after cloning the card to golden_image.img:
#      ./scripts/shrink-image.sh --compress golden_image.img
# =============================================================================
set -euo pipefail

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

case "${1:-}" in
  --prepare)
    grep -qi tegra /proc/version 2>/dev/null || { echo "Run --prepare ON THE JETSON." >&2; exit 1; }
    [ "$(id -u)" = 0 ] || { echo "Needs root: sudo $0 --prepare" >&2; exit 1; }

    echo "==> Clearing caches, logs, and history"
    apt-get clean
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* || true
    journalctl --vacuum-time=1d 2>/dev/null || true
    rm -f /home/*/.bash_history /root/.bash_history || true
    rm -rf /home/*/.cache/pip /root/.cache/pip || true

    echo "==> Removing SSH host keys (regenerated on first boot of each clone)"
    rm -f /etc/ssh/ssh_host_* || true
    cat > /etc/systemd/system/regen-ssh-hostkeys.service <<'UNIT'
[Unit]
Description=Regenerate SSH host keys on first boot
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/bin/systemctl restart ssh
[Install]
WantedBy=multi-user.target
UNIT
    systemctl enable regen-ssh-hostkeys.service || true

    echo "==> Zeroing free space (this fills the disk, then frees it — be patient)"
    dd if=/dev/zero of=/EMPTY bs=4M status=progress || true
    rm -f /EMPTY
    sync
    echo "==> Ready. Shut down, pull the card, and clone it."
    echo "    Host side:  sudo dd if=/dev/rdiskN of=golden_image.img bs=4m"
    ;;

  --compress)
    IMG="${2:-golden_image.img}"
    [ -f "$IMG" ] || { echo "Not found: $IMG" >&2; exit 1; }
    if command -v pigz >/dev/null; then
      echo "==> Compressing with pigz (all cores)"
      pigz -9 -k -f "$IMG"
    else
      echo "==> Compressing with gzip (install pigz to use all cores)"
      gzip -9 -k -f "$IMG"
    fi
    ls -lh "$IMG" "$IMG.gz"
    SHACMD=$(command -v sha256sum || echo "shasum -a 256")
    $SHACMD "$IMG.gz"
    ;;

  *) usage ;;
esac
