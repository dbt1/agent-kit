# agent-kit

Sprache: [English](README.md) | [Deutsch](README.de.md)

Generisches Bootstrap-Kit fuer agentengesteuerte Repository-Workflows.

## Was es macht

Beim ersten Aufruf von `claude`, `codex` oder `gemini` in einem Git-Repository
legt `agent-kit` automatisch eine konsistente Workflow-Struktur an:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (Profil-Symlinks)
- `MEMORY.md` (projektspezifischer Memory-Symlink)
- `SKILLS.md` (Skill-Uebersicht)
- `workitems/INDEX.md` und `workitems/template.md`
- `.agent-workflow/state.env` Marker

## Designziele

- Strikte Isolation: verhindert gemischte Legacy-/Neu-Zustaende
- Idempotenz
- Generische Defaults (kein Domain-Lock-in)
- Optionales Profil-Mapping ueber Konfigurationsdatei

## Schnellstart

Linux / WSL:

```bash
./bootstrap/install-auto-bootstrap.sh --activate-bashrc
source ~/.bashrc
```

Natives Windows PowerShell:

```powershell
powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1 --activate-profile
. $PROFILE
```

Danach `claude`, `codex` oder `gemini` im gewuenschten Git-Repo starten.

## Umgebung

- `AGENT_KIT_HOME`: absoluter Pfad zum Repo (wird im Wrapper aufgeloest)
- `AGENT_KIT_AUTOBOOTSTRAP=0`: Auto-Bootstrap fuer einen Aufruf deaktivieren
- `AGENT_KIT_STRICT_ISOLATION=1`: gemischte Legacy-Zustaende blockieren (Default)
- `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX`, `AGENT_KIT_REAL_GEMINI`:
  explizite Binary-Pfade fuer Wrapper

## Profil-Mapping

Optionale Pfad-Praefixe koennen in `config/project-map.tsv` hinterlegt werden:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

Format: `<absolutes-praefix><TAB><profilname>`

## Befehle

- `./bootstrap/bootstrap.sh` - aktuelles Repo oder `--project-root` bootstrappen
- `./bootstrap/bootstrap-all.sh` - alle Repos unter gegebenen Wurzeln bootstrappen
- `./bootstrap/install-auto-bootstrap.sh` - Wrapper installieren und aktivieren
- `powershell -NoProfile -File .\bootstrap\bootstrap.ps1` - nativer Windows-Bootstrap
- `powershell -NoProfile -File .\bootstrap\bootstrap-all.ps1` - nativer Windows-Bootstrap fuer mehrere Repos
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1` - native Wrapper-Installation unter Windows
- `./scripts/ci-smoke.sh` - lokale Syntax- und Smoke-Validierung
- `powershell -NoProfile -File .\scripts\ci-smoke.ps1` - lokale Windows-Syntax- und Smoke-Validierung

## Projektstatus-Datei

`state.env` liegt in `.agent-workflow/` und enthaelt Bootstrap-Version,
Profil und Pfadinformationen.

## Migration und Release

- `docs/migration.md` - sichere Migration und Rollback
- `docs/release.md` - Releaseprozess und Versionierung
- `CHANGELOG.md` - Aenderungshistorie
- `LICENSE` - MIT
