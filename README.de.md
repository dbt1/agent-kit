# agent-kit

Sprache: [English](README.md) | [Deutsch](README.de.md)

Generisches Bootstrap-Kit fuer agentengesteuerte Repository-Workflows.

## Was Ist Das

`agent-kit` installiert Wrapper-Befehle fuer konfigurierbare Agent-Namen
(Default: `codex`, `claude`, `gemini`), die beim ersten Agent-Aufruf in einem
Git-Repository automatisch eine konsistente Workflow-Struktur anlegen.

Bootstrap erzeugt:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (Profil-Links)
- `MEMORY.md` (Link auf den host-spezifischen Memory-Index)
- `SKILLS.md` (Skills-Link)
- `workitems/INDEX.md` und `workitems/template.md`
- `.agent-workflow/state.env` Marker

Zusaetzlich bereitet Bootstrap gemeinsamen Koordinationszustand unter
`AGENT_KIT_HOME` vor:

- `memory/projects/<project-id>/...` fuer host-aware Projekt-Memory
- `workitems/active/<project-id>/` fuer leichte Cross-Host-Aktivmeldungen

Außerhalb eines Git-Repositories wird der Bootstrap sauber zurückgestellt und
nach `git init` beim nächsten Wrapper-Aufruf automatisch erneut versucht.

## Voraussetzungen

Vor der Installation sicherstellen:

1. `git` ist installiert.
2. Mindestens eine echte Agent-CLI ist installiert und lauffaehig.
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

Standardmaessig pruefst du `codex`, `claude` und `gemini`. Mit eigener
Agent-Liste pruefst du stattdessen deine konfigurierten Namen.

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

## Agenten-Liste

- Sample-Liste im Repo: `config/agents.list.sample`
- Reale Liste fuer den Installer:
  - `AGENT_KIT_AGENT_LIST` (falls gesetzt)
  - sonst `config/agents.list` in `AGENT_KIT_HOME`, wenn beschreibbar
  - sonst Fallback `~/.config/agent-kit/agents.list`
- Beim ersten Install wird die reale Liste automatisch aus der Sample-Liste
  initialisiert und auf aktuell im PATH erkannte Commands gefiltert
  (Fallback: Sample-Defaults).
- Fuer zusaetzliche Commands Eintrag in der realen Liste setzen und Installer
  erneut ausfuehren.

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
6. Fuer Mehrhost-Koordination vor neuer Arbeit den Abschnitt `Active Work`
   in `MEMORY.md` pruefen.

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
  `AGENT_KIT_REAL_<AGENT_NAME>` (Uppercase, Nicht-Alnum als `_`) auf den realen
  Executable-Pfad setzen. Beispiel: `AGENT_KIT_REAL_CODEX`.
- Auto-Bootstrap einmalig deaktivieren:
  Befehl mit `AGENT_KIT_AUTOBOOTSTRAP=0` ausfuehren.
- Windows-Symlink-Rechte fehlen:
  Windows Developer Mode aktivieren oder PowerShell erhoeht starten, wenn echte
  Symlinks statt Copy-Fallback gewuenscht sind.

## Konfiguration

- `AGENT_KIT_HOME`: Pfad zu diesem Repository
- `AGENT_KIT_AGENT_LIST`: expliziter Pfad zur Agent-Command-Liste
- `AGENT_KIT_HOST_ID`: explizite Host-ID fuer host-aware Memory und host-spezifische Project-Maps
- `AGENT_KIT_AUTOBOOTSTRAP=0`: Auto-Bootstrap fuer einen Aufruf aus
- `AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS`: Liste von Projekt-Roots mit Auto-Refresh via `--force` (Windows `;`, Linux/WSL `:` getrennt; in der Praxis vor allem fuer Windows-Copy-Fallback sinnvoll)
- `AGENT_KIT_STRICT_ISOLATION=1`: gemischte Legacy-Zustaende blockieren (Default)
- `AGENT_KIT_ALLOW_COPY_FALLBACK=1`: Copy-Fallback erlauben, wenn Links nicht moeglich sind
- `AGENT_KIT_REAL_<AGENT_NAME>`: expliziter Binary-Pfad je Command-Name

Optionales Profil-Mapping per Pfad-Praefix:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

Datei: `config/project-map.tsv`
Format: `<absolute-path-prefix><TAB><profile-name>[<TAB><project-id>]`

## Host-Aware Koordination

`MEMORY.md` ist der kanonische Einstiegspunkt fuer Cross-Host-Projektkontext.

Lesereihenfolge:

1. Shared Knowledge
2. aktuelles Host-Memory
3. andere Host-Memorys nur als Referenz
4. `Active Work`-Verzeichnis fuer laufende Arbeiten anderer Hosts

Empfohlene Nutzung:

1. Vor neuer Arbeit `MEMORY.md` lesen.
2. Wenn die Aufgabe aktiv bearbeitet wird, die eigene Host-Claim-Datei unter
   `workitems/active/<project-id>/` anlegen oder aktualisieren.
3. Wenn die Aufgabe erledigt oder uebergeben ist, den Claim schliessen oder
   entfernen.
4. Dauerhafte Erkenntnisse in Shared- oder Host-Memory uebernehmen, nicht in
   Active-Claims belassen.

Host-spezifische Overrides sind moeglich ueber:

```text
config/project-map/<host-id>.tsv
```

Bootstrap nutzt diese Reihenfolge:

1. `config/project-map/<host-id>.tsv`
2. `config/project-map.tsv`

`project-id` ist optional. Wenn die Spalte fehlt, faellt Bootstrap auf den
sanitizten Projektordnernamen zurueck.

## Host-Aware Memory

Bootstrap schreibt Projekt-Memory in:

```text
memory/projects/<project-id>/
  shared.md
  hosts/<host-id>.md
  index/<host-id>.md
```

`MEMORY.md` im Projekt zeigt auf `index/<host-id>.md`.
Der Index legt fest: zuerst Shared Knowledge lesen, dann den lokalen Host-
Kontext, andere Hosts nur als Nachschlagewerk.

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
