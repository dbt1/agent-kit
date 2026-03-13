# agent-kit

Sprache: [English](README.md) | [Deutsch](README.de.md)

Generisches Bootstrap-Kit für agentengesteuerte Repository-Workflows.

## Was es macht

Beim ersten Aufruf von `claude`, `codex` oder `gemini` in einem Git-Repository
legt `agent-kit` automatisch eine konsistente Workflow-Struktur an:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (Profil-Symlinks)
- `MEMORY.md` (projektspezifischer Memory-Symlink)
- `SKILLS.md` (Skill-Übersicht)
- `workitems/INDEX.md` und `workitems/template.md`
- `.agent-workflow/state.env` Marker

## Designziele

- Strikte Isolation: verhindert gemischte Legacy-/Neu-Zustände
- Idempotenz
- Generische Defaults (kein Domain-Lock-in)
- Optionales Profil-Mapping über Konfigurationsdatei

## Schnellstart

```bash
./bootstrap/install-auto-bootstrap.sh --activate-bashrc
source ~/.bashrc
```

Danach `claude`, `codex` oder `gemini` im gewünschten Git-Repo starten.

## Umgebung

- `AGENT_KIT_HOME`: absoluter Pfad zum Repo (wird im Wrapper aufgelöst)
- `AGENT_KIT_AUTOBOOTSTRAP=0`: Auto-Bootstrap für einen Aufruf deaktivieren
- `AGENT_KIT_STRICT_ISOLATION=1`: gemischte Legacy-Zustände blockieren (Default)
- `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX`, `AGENT_KIT_REAL_GEMINI`:
  explizite Binary-Pfade für Wrapper

## Profil-Mapping

Optionale Pfad-Präfixe können in `config/project-map.tsv` hinterlegt werden:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

Format: `<absolutes-pfadpräfix><TAB><profilname>`

## Befehle

- `./bootstrap/bootstrap.sh` - aktuelles Repo oder `--project-root` bootstrappen
- `./bootstrap/bootstrap-all.sh` - alle Repos unter gegebenen Wurzeln bootstrappen
- `./bootstrap/install-auto-bootstrap.sh` - Wrapper installieren und aktivieren
- `./scripts/ci-smoke.sh` - lokale Syntax- und Smoke-Validierung

## Projektstatus-Datei

`state.env` liegt in `.agent-workflow/` und enthält Bootstrap-Version,
Profil und Pfadinformationen.

## Migration und Release

- `docs/migration.md` - sichere Migration und Rollback
- `docs/release.md` - Releaseprozess und Versionierung
- `CHANGELOG.md` - Änderungshistorie
- `LICENSE` - MIT
