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

Außerhalb eines Git-Repositories wird der Bootstrap sauber zurückgestellt und
nach `git init` beim nächsten Wrapper-Aufruf automatisch erneut versucht.

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

## Hinweise Zum Installationsort

- `agent-kit` selbst kann an beliebiger Stelle liegen, z. B.:
  - `C:\Users\<user>\source\agent-kit`
  - `D:\tools\agent-kit`
- Wrapper-Befehle werden standardmaessig pro Benutzer installiert:
  - Windows: `%USERPROFILE%\AppData\Local\agent-kit\bin`
  - Linux / WSL: `$HOME/.local/share/agent-kit/bin`
- Wrapper speichern den absoluten Pfad zur aktuellen `agent-kit`-Installation.
  Wenn `agent-kit` spaeter in einen anderen Ordner verschoben wird, den
  Installer erneut ausfuehren.
- Windows-Wrapper versuchen zusaetzlich Self-Heal:
  - zuerst `AGENT_KIT_HOME` aus der Umgebung
  - danach uebliche Pfade (`%USERPROFILE%\source\agent-kit`,
    `%USERPROFILE%\sources\agent-kit`, `%USERPROFILE%\dev\agent-kit`,
    `C:\tools\agent-kit`, `D:\tools\agent-kit`)
  - wenn nichts passt: Installer erneut ausfuehren

Benutzerdefiniertes Wrapper-Ziel:

```text
AGENT_KIT_INSTALL_DIR=<custom-bin-dir>
```

Danach Install-Skript erneut ausfuehren:

- `./bootstrap/install-auto-bootstrap.sh` (Linux / WSL)
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1` (Windows)

## Projektordner Anbinden

Es gibt keine separate Registrierungsdatei pro Projekt. Ein Projektordner gilt
als angebunden, sobald Bootstrap dort einmal erfolgreich gelaufen ist und
`.agent-workflow/state.env` existiert.

### Weg A: Automatisch ueber Wrapper (empfohlen)

1. Sicherstellen, dass der Projektordner ein Git-Repository ist.
   Falls noch keines existiert: `git init`.
2. In den Projektordner wechseln.
3. `codex`, `claude` oder `gemini` starten.
4. Der Wrapper triggert Bootstrap automatisch.
5. Pruefen, dass diese Dateien angelegt wurden:
   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `MEMORY.md`, `SKILLS.md`
   - `workitems/`
   - `.agent-workflow/state.env`

### Weg B: Manuell per Bootstrap-Skript

Nuetzlich fuer CI, Migrationsschritte oder wenn Wrapper nicht im PATH liegen.

Linux / WSL:

```bash
AGENT_KIT_HOME=/abs/pfad/zu/agent-kit \
/abs/pfad/zu/agent-kit/bootstrap/bootstrap.sh \
  --project-root /abs/pfad/zum/projekt \
  --agent codex
```

Windows PowerShell:

```powershell
$env:AGENT_KIT_HOME = "C:\abs\path\to\agent-kit"
powershell -NoProfile -File C:\abs\path\to\agent-kit\bootstrap\bootstrap.ps1 `
  --project-root C:\abs\path\to\project `
  --agent codex
```

## Windows-Link-Verhalten

Unter Windows versucht Bootstrap die Workflow-Dateien in dieser Reihenfolge:

1. Symbolischer Link
2. Hardlink (nur wenn `agent-kit` und Ziel-Repo auf demselben Laufwerk liegen)
3. Normale Datei-Kopie als Fallback (Default)

Damit funktioniert Bootstrap auch ohne Symlink-Rechte.

Wenn der Copy-Fallback genutzt wird:

- bleibt der Workflow im Alltag funktionsfaehig
- spaetere Aenderungen an `profiles/*.md` oder `SKILLS.md` in `agent-kit`
  werden nicht automatisch in bereits kopierte Projektdateien uebernommen
- fuer ein Refresh Bootstrap erneut mit `--force` ausfuehren
- optional: `AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS` setzen, um fuer ausgewaehlte
  Projekte automatisch mit `--force` zu refreshen (vor allem fuer Windows-
  Projekte mit Copy-Fallback)

Um den Copy-Fallback auszuschalten und stattdessen hart zu fehlschlagen:

```text
AGENT_KIT_ALLOW_COPY_FALLBACK=0
```

## Fehlerbehebung

- Strikte-Isolation-Block:
  Wenn unmanaged Workflow-Dateien gemeldet werden, in
  [Migration und Rollback](docs/migration.de.md) sauber migrieren.
- Wrapper findet den echten Befehl nicht:
  `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX` oder
  `AGENT_KIT_REAL_GEMINI` auf den realen Executable-Pfad setzen.
- Auto-Bootstrap einmalig deaktivieren:
  Befehl mit `AGENT_KIT_AUTOBOOTSTRAP=0` ausfuehren.
- Windows-Symlink-Rechte fehlen:
  Windows Developer Mode aktivieren oder PowerShell erhoeht starten, wenn echte
  Symlinks statt Copy-Fallback gewuenscht sind.

## Konfiguration

- `AGENT_KIT_HOME`: Pfad zu diesem Repository
- `AGENT_KIT_AUTOBOOTSTRAP=0`: Auto-Bootstrap fuer einen Aufruf aus
- `AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS`: Liste von Projekt-Roots mit Auto-Refresh via `--force` (Windows `;`, Linux/WSL `:` getrennt; in der Praxis vor allem fuer Windows-Copy-Fallback sinnvoll)
- `AGENT_KIT_STRICT_ISOLATION=1`: gemischte Legacy-Zustaende blockieren (Default)
- `AGENT_KIT_ALLOW_COPY_FALLBACK=1`: Copy-Fallback erlauben, wenn Links nicht moeglich sind
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
