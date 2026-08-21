#!/usr/bin/env bash
# =============================================================================
#  verify.sh — Confirm a local image matches the published SHA-256
#  Usage:  ./scripts/verify.sh [image]
# =============================================================================
set -euo pipefail
IMAGE="${1:-golden_image.img.gz}"
[ -f "$IMAGE" ] || { echo "Not found: $IMAGE" >&2; exit 1; }
SHACMD=$(command -v sha256sum || echo "shasum -a 256")

echo "==> Hashing $IMAGE ($(du -h "$IMAGE" | cut -f1)) — a few minutes"
ACTUAL=$($SHACMD "$IMAGE" | awk '{print $1}')
echo "    actual   : $ACTUAL"

if [ -f CHECKSUMS.txt ]; then
  EXPECTED=$(awk -v f="$(basename "$IMAGE")" '$2==f || $2=="*"f {print $1}' CHECKSUMS.txt | head -1)
  echo "    expected : ${EXPECTED:-<not listed in CHECKSUMS.txt>}"
  [ "$ACTUAL" = "$EXPECTED" ] && echo "==> MATCH" || { echo "==> MISMATCH" >&2; exit 1; }
else
  echo "    (no CHECKSUMS.txt in repo root — compare against the release page manually)"
fi
