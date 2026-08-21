#!/usr/bin/env bash
# =============================================================================
#  publish-release.sh — Upload the split image to a GitHub Release
#
#  Requires the GitHub CLI:  https://cli.github.com  (gh auth login)
#
#  Usage:  ./scripts/publish-release.sh v1.0.0 [image-parts-dir]
#          ./scripts/publish-release.sh --dry-run v1.0.0    # show, touch nothing
#
#  Publishing is IRREVERSIBLE: a public release is mirrored and indexed within
#  minutes. This script asks before it creates anything, and --dry-run lets you
#  exercise the whole path (including the secret-scan gate) without side
#  effects. Use --dry-run for any testing.
# =============================================================================
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
args=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    *)         args+=("$a") ;;
  esac
done
set -- "${args[@]:-}"

TAG="${1:-}"
PARTS="${2:-image-parts}"
[ -n "$TAG" ] || { echo "Usage: $0 [--dry-run] [--yes] <tag> [parts-dir]" >&2; exit 1; }
[ "$DRY_RUN" = 1 ] && echo "*** DRY RUN — nothing will be created or uploaded ***"
command -v gh >/dev/null || { echo "gh (GitHub CLI) is required: https://cli.github.com" >&2; exit 1; }
[ -d "$PARTS" ] || { echo "No parts directory '$PARTS'. Run ./scripts/split-image.sh first." >&2; exit 1; }

# ── secret scan gate ─────────────────────────────────────────────────────────
# Publishing is irreversible: once 10 GB of image is public it is mirrored,
# indexed, and cannot be recalled. Refuse to upload without a passing scan.
REPORT="${REPORT:-scan-report.txt}"
if [ "${SKIP_SCAN:-0}" = "1" ]; then
  echo "!! SKIP_SCAN=1 — publishing WITHOUT a credential scan. On your head be it."
elif [ ! -f "$REPORT" ]; then
  cat >&2 <<EOF
No $REPORT found. Scan the image before publishing it:

    ./scripts/scan-image.sh

A golden image carries whatever was on the source card — Wi-Fi passwords, SSH
keys, shell history, API tokens. A public release cannot be recalled.
Override with SKIP_SCAN=1 only if you know exactly why.
EOF
  exit 1
elif ! grep -q '^result: CLEAN' "$REPORT"; then
  echo "$REPORT does not say CLEAN — refusing to publish. Findings:" >&2
  sed -n '/BLOCK/p' "$REPORT" >&2
  exit 1
else
  echo "==> Secret scan gate: $REPORT is CLEAN"
fi

TOTAL=$(cat "$PARTS"/* | wc -c 2>/dev/null || echo 0)
cat <<EOF

  Repository .... $(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo '?')
  Tag ........... $TAG
  Assets ........ $(find "$PARTS" -type f | wc -l | tr -d ' ') files, $(( TOTAL / 1000000 )) MB
  Visibility .... public, permanent, mirrored within minutes

EOF

if [ "$DRY_RUN" = 1 ]; then
  echo "Would create release $TAG and upload:"
  find "$PARTS" -type f -exec basename {} \; | sed 's/^/    /'
  echo
  echo "Dry run complete — nothing was created."
  exit 0
fi

if [ "$ASSUME_YES" != 1 ]; then
  read -r -p "Publish this release? Type the tag ($TAG) to confirm: " CONFIRM
  [ "$CONFIRM" = "$TAG" ] || { echo "Aborted — nothing was published."; exit 1; }
fi

if ! gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Creating release $TAG"
  gh release create "$TAG" \
    --title "Jetson Nano YOLOv5-OP Golden Image $TAG" \
    --notes-file docs/RELEASE_NOTES.md
fi

echo "==> Uploading assets (this is ~10 GB — grab a coffee)"
echo "    Safe to re-run: --clobber replaces partial uploads."
gh release upload "$TAG" "$PARTS"/* --clobber

echo
echo "==> Done. Assets on release $TAG:"
gh release view "$TAG" --json assets --jq '.assets[] | "\(.name)  \(.size/1048576 | floor) MiB"'
