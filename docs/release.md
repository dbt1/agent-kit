# Release Process

Language: [English](release.md) | [Deutsch](release.de.md)

## Goals

- Keep releases reproducible
- Ensure bootstrap behavior stays stable
- Avoid shipping untested shell changes

## Versioning

Use Semantic Versioning (`MAJOR.MINOR.PATCH`).

- `MAJOR`: breaking changes in bootstrap behavior or file contracts
- `MINOR`: backwards-compatible features
- `PATCH`: bug fixes and docs-only operational fixes

## Pre-release checklist

1. Run local checks:
   - `bash -n` on all shell scripts
   - `scripts/ci-smoke.sh`
   - `powershell -NoProfile -File .\scripts\ci-smoke.ps1`
2. Confirm docs are aligned:
   - `README.md`
   - `docs/migration.md`
   - `CHANGELOG.md`
3. Ensure generated files are not committed (`memory/*_MEMORY.md`).

## Tagging

```bash
git tag -a v0.1.0 -m "release: v0.1.0"
git push origin v0.1.0
```

## Post-release

- Verify GitHub Actions passed for the release commit
- Announce key changes and migration notes
