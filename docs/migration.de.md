# Migration und Rollback

Sprache: [English](migration.md) | [Deutsch](migration.de.md)

Dieser Leitfaden ist fuer Repositories gedacht, die bereits `AGENTS.md`,
`CLAUDE.md`, `MEMORY.md` oder andere Workflow-Dateien enthalten.

## Sichere Migrationsstrategie

1. Bootstrap zuerst im Dry-Run ausfuehren.
2. Geplante Aenderungen pruefen.
3. Nur anwenden, wenn alles passt.
4. Vorher einen einfachen Snapshot fuer Rollback behalten.

## Beispiel: Dry-Run

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --dry-run
```

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\pfad\zum\repo --dry-run
```

## Beispiel: Anwenden

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --force
```

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\pfad\zum\repo --force
```

`--force` nur verwenden, wenn der Plan vorher geprueft wurde.

## Verhalten bei strikter Isolation

Standardmaessig blockiert Bootstrap nicht verwaltete Dateien/Symlinks in:

- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`
- `MEMORY.md`
- `SKILLS.md`

Zum bewussten Umgehen fuer manuelle Migrationslaeufe:

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --no-strict --force
```

```powershell
powershell -NoProfile -File .\bootstrap\bootstrap.ps1 --project-root C:\pfad\zum\repo --no-strict --force
```

## Windows-Link-Einschraenkungen

Unter Windows versucht Bootstrap zuerst Symlinks, dann Hardlinks, dann
Datei-Kopien.

- Hardlinks funktionieren nur auf demselben Laufwerk (z. B. `C:` nach `C:`).
- Liegt `agent-kit` auf `C:` und das Ziel-Repo auf `D:`, ist der
  Hardlink-Fallback nicht moeglich.
- In diesem Fall kann Bootstrap trotzdem erfolgreich mit Datei-Kopien abschliessen.

Wenn Kopien verwendet wurden und spaeter `profiles/*.md` oder `SKILLS.md`
geaendert werden, Bootstrap mit `--force` erneut ausfuehren, um Projektdateien
zu aktualisieren.

## Rollback

Rollback ist dateibasiert:

1. Vorherige Symlink-Ziele fuer Workflow-Dateien wiederherstellen.
2. Generierte Dateien entfernen, falls sie vorher nicht existierten:
   - `.agent-workflow/state.env`
   - `workitems/INDEX.md`
   - `workitems/template.md`
3. Falls vorhanden, das vorherige Setup-Skript erneut ausfuehren.
