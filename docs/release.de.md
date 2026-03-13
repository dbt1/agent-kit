# Release-Prozess

Sprache: [English](release.md) | [Deutsch](release.de.md)

## Ziele

- Reproduzierbare Releases
- Stabiles Bootstrap-Verhalten über Versionen
- Keine ungetesteten Shell-Änderungen ausliefern

## Versionierung

Semantic Versioning verwenden (`MAJOR.MINOR.PATCH`).

- `MAJOR`: Breaking Changes im Bootstrap-Verhalten oder Dateiverträgen
- `MINOR`: abwärtskompatible Erweiterungen
- `PATCH`: Bugfixes und operative Doku-Korrekturen

## Pre-Release-Checkliste

1. Lokale Checks ausführen:
   - `bash -n` auf allen Shell-Skripten
   - `scripts/ci-smoke.sh`
2. Dokumentation auf Konsistenz prüfen:
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

- Prüfen, dass GitHub Actions für den Release-Commit grün sind
- Wichtige Änderungen und Migrationshinweise kommunizieren
