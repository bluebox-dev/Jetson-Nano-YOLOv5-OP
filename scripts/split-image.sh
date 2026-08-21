#!/usr/bin/env bash
# =============================================================================
#  split-image.sh — Split the golden image into GitHub-Release-sized chunks
#
#  GitHub caps a single release asset at 2 GB, so the 10.25 GiB image ships as
#  numbered parts plus a SHA-256 manifest. Run this once before publishing.
#
#  Usage:  ./scripts/split-image.sh [image] [output-dir]
#  Default: golden_image.img.gz  ->  image-parts/golden_image.img.gz.part-aa …
# =============================================================================
set -euo pipefail

IMAGE="${1:-golden_image.img.gz}"
OUTDIR="${2:-image-parts}"
CHUNK="${CHUNK:-1900M}"   # comfortably under GitHub's 2 GB asset limit

[ -f "$IMAGE" ] || { echo "Image not found: $IMAGE" >&2; exit 1; }

BASE="$(basename "$IMAGE")"
mkdir -p "$OUTDIR"

echo "==> Splitting $BASE into ${CHUNK} chunks"
# GNU split and newer BSD/macOS split both take -d (numeric suffixes); older
# BSD split does not, so fall back to letter suffixes if -d is rejected.
if split -b "$CHUNK" -d -a 2 /dev/null "$OUTDIR/.probe-" 2>/dev/null; then
  SPLIT_OPTS=(-b "$CHUNK" -d -a 2)
else
  SPLIT_OPTS=(-b "$CHUNK" -a 2)
fi
rm -f "$OUTDIR"/.probe-* 2>/dev/null || true
split "${SPLIT_OPTS[@]}" "$IMAGE" "$OUTDIR/${BASE}.part-"

echo "==> Hashing"
SHACMD=$(command -v sha256sum || echo "shasum -a 256")
(
  cd "$OUTDIR"
  # shellcheck disable=SC2086
  $SHACMD "${BASE}".part-* > SHA256SUMS
)
# whole-image hash, for the final joined file
# shellcheck disable=SC2086
$SHACMD "$IMAGE" | awk -v f="$BASE" '{print $1"  "f}' >> "$OUTDIR/SHA256SUMS"

echo
echo "==> Parts written to $OUTDIR/"
ls -lh "$OUTDIR"
echo
echo "Next:  ./scripts/publish-release.sh v1.0.0"
