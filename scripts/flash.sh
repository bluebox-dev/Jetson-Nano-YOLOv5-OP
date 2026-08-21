#!/usr/bin/env bash
# =============================================================================
#  flash.sh — Write the Jetson Nano YOLOv5-OP golden image to a microSD card
#
#  Usage:
#     ./scripts/flash.sh                       # interactive: pick a device
#     ./scripts/flash.sh /dev/disk4            # macOS
#     ./scripts/flash.sh /dev/sdb              # Linux
#     IMAGE=./golden_image.img.gz ./scripts/flash.sh /dev/sdb
#
#  Safety: refuses to touch the boot/system disk, always asks for confirmation,
#  and prints exactly what it is about to destroy before it does anything.
# =============================================================================
set -euo pipefail

IMAGE="${IMAGE:-golden_image.img.gz}"
BLOCK_SIZE="${BLOCK_SIZE:-4m}"
MIN_CARD_BYTES=31138512896   # 29.00 GiB — the raw size of the golden image

# ── pretty output ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  B=$'\033[1m'; R=$'\033[0m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; CYA=$'\033[36m'
else
  B=""; R=""; RED=""; GRN=""; YEL=""; CYA=""
fi
info() { printf '%s[ i ]%s %s\n' "$CYA" "$R" "$*"; }
ok()   { printf '%s[ ✔ ]%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s[ ! ]%s %s\n' "$YEL" "$R" "$*"; }
die()  { printf '%s[ ✘ ]%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }

OS="$(uname -s)"
case "$OS" in
  Darwin|Linux) ;;
  *) die "Unsupported OS: $OS. On Windows use Balena Etcher or Raspberry Pi Imager (see docs/FLASHING.md)." ;;
esac

# ── locate the image ─────────────────────────────────────────────────────────
[ -f "$IMAGE" ] || die "Image not found: $IMAGE
      Download it first:  ./scripts/download-image.sh
      Or point at your own copy:  IMAGE=/path/to/golden_image.img.gz $0 <device>"

# ── list candidate removable devices ─────────────────────────────────────────
list_devices() {
  if [ "$OS" = "Darwin" ]; then
    diskutil list external physical 2>/dev/null || diskutil list
  else
    lsblk -dpo NAME,SIZE,TYPE,RM,MODEL | awk 'NR==1 || $4==1'
  fi
}

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo
  printf '%sRemovable devices detected:%s\n' "$B" "$R"
  list_devices
  echo
  read -r -p "Enter the target device (e.g. /dev/disk4 or /dev/sdb): " DEVICE
fi
[ -n "$DEVICE" ] || die "No device given."
[ -b "$DEVICE" ] || [ -c "$DEVICE" ] || die "Not a block device: $DEVICE"

# ── refuse to nuke the system disk ───────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then
  ROOT_DISK="/dev/$(diskutil info / 2>/dev/null | awk -F': *' '/Part of Whole/{print $2}')"
else
  ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
  ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1)"
fi
case "$DEVICE" in
  "$ROOT_DISK"|"$ROOT_DISK"[0-9]*|"${ROOT_DISK}p"[0-9]*)
    die "$DEVICE is (part of) your system disk $ROOT_DISK. Refusing." ;;
esac

# ── capacity check ───────────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then
  DEV_BYTES="$(diskutil info "$DEVICE" | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')"
  DEV_DESC="$(diskutil info "$DEVICE" | awk -F': *' '/Device \/ Media Name/{print $2; exit}')"
else
  DEV_BYTES="$(sudo blockdev --getsize64 "$DEVICE" 2>/dev/null || blockdev --getsize64 "$DEVICE" 2>/dev/null || echo 0)"
  DEV_DESC="$(lsblk -dno MODEL "$DEVICE" 2>/dev/null || echo unknown)"
fi
case "$DEV_BYTES" in (*[!0-9]*|"") DEV_BYTES=0 ;; esac   # non-numeric -> skip the check
if [ "$DEV_BYTES" -gt 0 ] && [ "$DEV_BYTES" -lt "$MIN_CARD_BYTES" ]; then
  die "Card is too small: $(( DEV_BYTES / 1000000000 )) GB. The image needs a 32 GB card or larger."
fi

# ── the point of no return ───────────────────────────────────────────────────
cat <<EOF

  ${B}Target${R} ......... $DEVICE  ($DEV_DESC, $(( DEV_BYTES / 1000000000 )) GB)
  ${B}Image${R} .......... $IMAGE
  ${B}Writes${R} ......... 29.0 GiB, raw, from sector 0

${RED}${B}  EVERYTHING ON $DEVICE WILL BE PERMANENTLY DESTROYED.${R}

EOF
read -r -p "Type ERASE to continue: " CONFIRM
[ "$CONFIRM" = "ERASE" ] || die "Aborted — nothing was written."

# ── unmount ──────────────────────────────────────────────────────────────────
info "Unmounting $DEVICE ..."
if [ "$OS" = "Darwin" ]; then
  diskutil unmountDisk "$DEVICE" || die "Could not unmount $DEVICE"
  RAW="/dev/r${DEVICE#/dev/}"          # rdisk = raw device, ~10x faster on macOS
else
  for p in "$DEVICE"?*; do [ -e "$p" ] && sudo umount "$p" 2>/dev/null || true; done
  RAW="$DEVICE"
fi

# ── write ────────────────────────────────────────────────────────────────────
DECOMP=(gzip -dc)
command -v pigz >/dev/null 2>&1 && DECOMP=(pigz -dc)   # multi-core, much faster

info "Writing with ${DECOMP[0]} → dd (bs=$BLOCK_SIZE). This takes 15–45 minutes."
info "Press Ctrl-T (macOS) or send SIGUSR1 to dd (Linux) for progress."

if command -v pv >/dev/null 2>&1; then
  "${DECOMP[@]}" "$IMAGE" | pv -s "$MIN_CARD_BYTES" | sudo dd of="$RAW" bs="$BLOCK_SIZE"
elif [ "$OS" = "Linux" ]; then
  "${DECOMP[@]}" "$IMAGE" | sudo dd of="$RAW" bs="$BLOCK_SIZE" status=progress conv=fsync
else
  "${DECOMP[@]}" "$IMAGE" | sudo dd of="$RAW" bs="$BLOCK_SIZE"
fi

sync
ok "Write complete."

info "Ejecting ..."
if [ "$OS" = "Darwin" ]; then diskutil eject "$DEVICE" || true; else sudo eject "$DEVICE" 2>/dev/null || true; fi

cat <<EOF

${GRN}${B}  Done.${R} Put the card in the Jetson Nano and power on.
  First boot takes 2–4 minutes while the root filesystem expands.
  Next: docs/FIRST_BOOT.md

EOF
