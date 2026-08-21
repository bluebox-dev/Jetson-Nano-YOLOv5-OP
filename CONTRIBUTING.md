# Contributing

Thanks for helping. This repo is small on purpose: documentation, flashing
tooling, and the release pipeline for the image. The image itself is built by
hand on real hardware following [docs/BUILD_FROM_SCRATCH.md](docs/BUILD_FROM_SCRATCH.md).

## Ground rules

**Never publish an unscanned image.** `scripts/scan-image.sh` must pass before
`publish-release.sh` will upload anything, and `--dry-run` exercises the whole
path without touching GitHub. Use `--dry-run` for any testing — running the
real script with a throwaway tag creates a real public release.

**Never commit the image.** Not the `.img`, not the `.img.gz`, not the split
parts. `.gitignore` covers the usual names and CI fails any file over 50 MB.
Images ship as GitHub Release assets — see `scripts/split-image.sh`.

**Test scripts before submitting.** `flash.sh` writes to block devices; a
plausible-looking untested change to it can destroy someone's disk. Run it.

**Keep claims verifiable.** If you state a version, say where it came from
(`/etc/nv_tegra_release`, `dpkg -l`, the JetPack release notes). Rows in
`docs/IMAGE_CONTENTS.md` that are inferred rather than inspected are marked
*(JetPack baseline)* — please keep that distinction.

## What's most useful

| | |
|---|---|
| **Benchmark results** | The biggest gap. `./scripts/benchmark.sh` on the device, then open a PR against `docs/BENCHMARKS.md`. |
| **Host OS quirks** | Flashing gotchas on Windows, unusual card readers, WSL. |
| **Camera recipes** | Working GStreamer pipelines for cameras beyond IMX219. |
| **Troubleshooting entries** | Something broke and you fixed it? Write it down for the next person. |

## Development

```bash
shellcheck scripts/*.sh        # CI runs this at severity=warning
bash -n scripts/*.sh           # quick syntax check
```

## Commit messages

Plain and descriptive. `docs: add IMX477 pipeline` beats `update`.

## Reporting security issues

If you find credentials, keys, or personal data left in a published image, please
open a **private** security advisory rather than a public issue, so the release
can be pulled first.
