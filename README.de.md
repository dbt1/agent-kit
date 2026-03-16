# agent-kit

Sprache: [English](README.md) | [Deutsch](README.de.md)

Generisches Bootstrap-Kit fuer agentengesteuerte Repository-Workflows.

## Was Ist Das

`agent-kit` installiert kleine Wrapper-Befehle (`claude`, `codex`, `gemini`),
die beim ersten Agent-Aufruf in einem Git-Repository automatisch eine
konsistente Workflow-Struktur anlegen.

Bootstrap erzeugt:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (Profil-Links)
- `MEMORY.md` (Projekt-Memory-Link)
- `SKILLS.md` (Skills-Link)
- `workitems/INDEX.md` und `workitems/template.md`
- `.agent-workflow/state.env` Marker

## Voraussetzungen

Vor der Installation sicherstellen:

1. `git` ist installiert.
2. Mindestens eine echte Agent-CLI ist installiert und lauffaehig (`claude`,
   `codex` oder `gemini`).
3. Du nutzt entweder:
   - Linux / WSL mit Bash
   - Windows mit PowerShell

## Installation (Schritt fuer Schritt)

### 1. Repository klonen

```bash
git clone <deine-agent-kit-repo-url> agent-kit
cd agent-kit
```

### 2. Wrapper-Befehle installieren

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

### 3. Installation pruefen

Linux / WSL:

```bash
command -v codex
command -v claude
command -v gemini
```

Windows PowerShell:

```powershell
Get-Command codex
Get-Command claude
Get-Command gemini
```

Die angezeigten Pfade sollten auf das lokale Wrapper-Verzeichnis zeigen.

## Erste Nutzung In Einem Projekt

1. Beliebiges Git-Repository oeffnen.
2. Einen Agent-Befehl starten (z. B. `codex`).
3. Pruefen, dass diese Dateien angelegt wurden:
   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `MEMORY.md`, `SKILLS.md`
   - `workitems/`
   - `.agent-workflow/state.env`

## Fehlerbehebung

- Strikte-Isolation-Block:
  Wenn unmanaged Workflow-Dateien gemeldet werden, in
  [Migration und Rollback](docs/migration.de.md) sauber migrieren.
- Wrapper findet den echten Befehl nicht:
  `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX` oder
  `AGENT_KIT_REAL_GEMINI` auf den realen Executable-Pfad setzen.
- Auto-Bootstrap einmalig deaktivieren:
  Befehl mit `AGENT_KIT_AUTOBOOTSTRAP=0` ausfuehren.

## Konfiguration

- `AGENT_KIT_HOME`: Pfad zu diesem Repository
- `AGENT_KIT_AUTOBOOTSTRAP=0`: Auto-Bootstrap fuer einen Aufruf aus
- `AGENT_KIT_STRICT_ISOLATION=1`: gemischte Legacy-Zustaende blockieren (Default)
- `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX`, `AGENT_KIT_REAL_GEMINI`:
  explizite Pfade zu echten Binaries

Optionales Profil-Mapping per Pfad-Praefix:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

Datei: `config/project-map.tsv`  
Format: `<absolutes-praefix><TAB><profilname>`

## Befehlsreferenz

- `./bootstrap/bootstrap.sh`: aktuelles Repo oder `--project-root` bootstrappen
- `./bootstrap/bootstrap-all.sh`: alle Repos unter Root-Pfaden bootstrappen
- `./bootstrap/install-auto-bootstrap.sh`: Bash-Wrapper installieren
- `powershell -NoProfile -File .\bootstrap\bootstrap.ps1`: Windows-Bootstrap
- `powershell -NoProfile -File .\bootstrap\bootstrap-all.ps1`: Windows-Bootstrap fuer mehrere Repos
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1`: Windows-Wrapper installieren
- `./scripts/ci-smoke.sh`: Bash-Smoke-Checks
- `powershell -NoProfile -File .\scripts\ci-smoke.ps1`: PowerShell-Smoke-Checks

## Dokumentations-Uebersicht

- [Migration und Rollback](docs/migration.de.md) ([EN](docs/migration.md))
- [Release-Prozess](docs/release.de.md) ([EN](docs/release.md))
- [Aenderungshistorie](CHANGELOG.md)
- [Lizenz](LICENSE)
