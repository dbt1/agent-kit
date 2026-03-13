# Migration und Rollback

Sprache: [English](migration.md) | [Deutsch](migration.de.md)

Dieser Leitfaden ist für Repositories gedacht, die bereits `AGENTS.md`,
`CLAUDE.md`, `MEMORY.md` oder andere Workflow-Dateien enthalten.

## Sichere Migrationsstrategie

1. Bootstrap zuerst im Dry-Run ausführen.
2. Geplante Änderungen prüfen.
3. Nur anwenden, wenn alles passt.
4. Vorher einen einfachen Snapshot für Rollback behalten.

## Beispiel: Dry-Run

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --dry-run
```

## Beispiel: Anwenden

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --force
```

`--force` nur verwenden, wenn der Plan vorher geprüft wurde.

## Verhalten bei strikter Isolation

Standardmäßig blockiert Bootstrap nicht verwaltete Dateien/Symlinks in:

- `AGENTS.md`
- `CLAUDE.md`
- `GEMINI.md`
- `MEMORY.md`
- `SKILLS.md`

Zum bewussten Umgehen für manuelle Migrationsläufe:

```bash
./bootstrap/bootstrap.sh --project-root /pfad/zum/repo --no-strict --force
```

## Rollback

Rollback ist dateibasiert:

1. Vorherige Symlink-Ziele für Workflow-Dateien wiederherstellen.
2. Generierte Dateien entfernen, falls sie vorher nicht existierten:
   - `.agent-workflow/state.env`
   - `workitems/INDEX.md`
   - `workitems/template.md`
3. Falls vorhanden, das vorherige Setup-Skript erneut ausführen.
