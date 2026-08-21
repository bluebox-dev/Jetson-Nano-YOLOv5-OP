#!/usr/bin/env bash
# =============================================================================
#  scan-image.sh — Look for credentials in an image BEFORE publishing it
#
#  A golden image is a byte-for-byte copy of a real, used system. Whatever was
#  on the source card ships to everyone who flashes it, and a public release
#  cannot be recalled. Run this every time, before every release.
#
#  Usage:  ./scripts/scan-image.sh [image]        (default golden_image.img.gz)
#  Writes: scan-report.txt   (consumed by publish-release.sh as a gate)
#
#  Exit 0 = clean, 1 = credentials found (do not publish).
#  Secret VALUES are never printed — only kind, count, and length.
# =============================================================================
set -euo pipefail
IMAGE="${1:-golden_image.img.gz}"
REPORT="${REPORT:-scan-report.txt}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -f "$IMAGE" ] || { echo "Image not found: $IMAGE" >&2; exit 1; }

echo "==> Scanning $IMAGE — one full pass, several minutes"
python3 "$HERE/scan_image.py" "$IMAGE" --report "$REPORT"
rc=$?

echo
echo "==> Report written to $REPORT"
if [ "$rc" -eq 0 ]; then
  cat <<'EOF'

Reminder — a clean scan is not the same as a sanitised image:
  * /etc/shadow still carries the password hash for every user. Every person
    who flashes the card can crack it offline. Document that users must run
    `passwd` on first boot.
  * Run scripts/shrink-image.sh --prepare on the Jetson before cloning to
    strip shell history, caches, and SSH host keys.
EOF
fi
exit "$rc"
