# Release-Prozess

Sprache: [English](release.md) | [Deutsch](release.de.md)

## Ziele

- Reproduzierbare Releases
- Stabiles Bootstrap-Verhalten ueber Versionen
- Keine ungetesteten Shell-Aenderungen ausliefern

## Versionierung

Semantic Versioning verwenden (`MAJOR.MINOR.PATCH`).

- `MAJOR`: Breaking Changes im Bootstrap-Verhalten oder Dateivertraegen
- `MINOR`: abwaertskompatible Erweiterungen
- `PATCH`: Bugfixes und operative Doku-Korrekturen

## Pre-Release-Checkliste

1. Lokale Checks ausfuehren:
   - `bash -n` auf allen Shell-Skripten
   - `scripts/ci-smoke.sh`
   - `powershell -NoProfile -File .\scripts\ci-smoke.ps1`
2. Dokumentation auf Konsistenz pruefen:
   - `README.md`
   - `docs/migration.md`
   - `CHANGELOG.md`
3. Sicherstellen, dass generierte Dateien nicht committed werden
   (`memory/*_MEMORY.md`).

## Tagging

```bash
git tag -a v0.1.0 -m "release: v0.1.0"
git push origin v0.1.0
```

## Nach dem Release

- Pruefen, dass GitHub Actions fuer den Release-Commit gruen sind
- Wichtige Aenderungen und Migrationshinweise kommunizieren
