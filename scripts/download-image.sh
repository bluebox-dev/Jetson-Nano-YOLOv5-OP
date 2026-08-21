#!/usr/bin/env bash
# =============================================================================
#  download-image.sh — Fetch the golden image from GitHub Releases,
#                      verify every part, and reassemble it.
#
#  Usage:  ./scripts/download-image.sh [tag]     (default: latest)
#  Result: ./golden_image.img.gz
# =============================================================================
set -euo pipefail

REPO="${REPO:-bluebox-dev/Jetson-Nano-YOLOv5-OP}"
TAG="${1:-latest}"
PARTS="${PARTS:-image-parts}"
BASE="golden_image.img.gz"

command -v gh >/dev/null || { echo "gh (GitHub CLI) is required: https://cli.github.com" >&2; exit 1; }

mkdir -p "$PARTS"
echo "==> Downloading $TAG from $REPO (~10 GB, resumable — rerun if interrupted)"
if [ "$TAG" = "latest" ]; then
  gh release download --repo "$REPO" --dir "$PARTS" --pattern '*' --clobber
else
  gh release download "$TAG" --repo "$REPO" --dir "$PARTS" --pattern '*' --clobber
fi

echo "==> Verifying parts"
SHACMD=$(command -v sha256sum || echo "shasum -a 256")
( cd "$PARTS" && grep -- "-part-" SHA256SUMS | $SHACMD -c - ) \
  || { echo "Checksum mismatch — delete $PARTS and download again." >&2; exit 1; }

echo "==> Reassembling $BASE"
cat "$PARTS/${BASE}.part-"* > "$BASE"

echo "==> Verifying the joined image"
EXPECTED=$(awk -v f="$BASE" '$2==f{print $1}' "$PARTS/SHA256SUMS")
ACTUAL=$($SHACMD "$BASE" | awk '{print $1}')
if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "FAILED: expected $EXPECTED, got $ACTUAL" >&2; exit 1
fi

echo
echo "OK — $BASE is ready. Flash it with:  ./scripts/flash.sh"
