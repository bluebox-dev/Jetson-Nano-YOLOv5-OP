#!/usr/bin/env bash
# =============================================================================
#  publish-release.sh — Upload the split image to a GitHub Release
#
#  Requires the GitHub CLI:  https://cli.github.com  (gh auth login)
#  Usage:  ./scripts/publish-release.sh v1.0.0 [image-parts-dir]
# =============================================================================
set -euo pipefail

TAG="${1:-}"
PARTS="${2:-image-parts}"
[ -n "$TAG" ] || { echo "Usage: $0 <tag> [parts-dir]" >&2; exit 1; }
command -v gh >/dev/null || { echo "gh (GitHub CLI) is required: https://cli.github.com" >&2; exit 1; }
[ -d "$PARTS" ] || { echo "No parts directory '$PARTS'. Run ./scripts/split-image.sh first." >&2; exit 1; }

if ! gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Creating release $TAG"
  gh release create "$TAG" \
    --title "Jetson Nano YOLOv5-OP Golden Image $TAG" \
    --notes-file docs/RELEASE_NOTES.md
fi

echo "==> Uploading assets (this is ~10 GB — grab a coffee)"
gh release upload "$TAG" "$PARTS"/* --clobber

echo
echo "==> Done. Assets on release $TAG:"
gh release view "$TAG" --json assets --jq '.assets[] | "\(.name)  \(.size/1048576 | floor) MiB"'
