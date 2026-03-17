# agent-kit

Language: [English](README.md) | [Deutsch](README.de.md)

Generic bootstrap kit for agent-driven repository workflows.

## What This Is

`agent-kit` installs wrapper commands for configured agent names (default:
`codex`, `claude`, `gemini`) that auto-bootstrap a consistent workflow layout
the first time you run an agent inside a Git repository.

Bootstrap creates:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (profile links)
- `MEMORY.md` (project memory link)
- `SKILLS.md` (skills link)
- `workitems/INDEX.md` and `workitems/template.md`
- `.agent-workflow/state.env` marker

If called outside a Git repository, bootstrap is deferred gracefully and retried
automatically after `git init` on the next wrapped agent call.

## Prerequisites

Before installation, ensure:

1. `git` is installed.
2. At least one real agent CLI is installed and runnable.
3. You are on either:
   - Linux / WSL with Bash
   - Windows with PowerShell

## Installation (Step by Step)

### 1. Clone this repository

```bash
git clone <your-agent-kit-repo-url> agent-kit
cd agent-kit
```

### 2. Install wrapper commands

Linux / WSL:

```bash
./bootstrap/install-auto-bootstrap.sh --activate-bashrc
source ~/.bashrc
```

Native Windows PowerShell:

```powershell
powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1 --activate-profile
. $PROFILE
```

### 3. Verify installation

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

You should see command paths from the local wrapper install directory.

By default, verify `codex`, `claude`, and `gemini`. If you use a custom agent
list, verify those configured command names instead.

## Install Location Notes

- `agent-kit` itself can be cloned anywhere, for example:
  - `C:\Users\<user>\source\agent-kit`
  - `D:\tools\agent-kit`
- Wrapper commands are installed per user by default:
  - Windows: `%USERPROFILE%\AppData\Local\agent-kit\bin`
  - Linux / WSL: `$HOME/.local/share/agent-kit/bin`
- Wrappers store the absolute path to the current `agent-kit` install.
  If you move `agent-kit` to a different folder later, run installer again.
- Windows wrappers also try to self-heal:
  - first `AGENT_KIT_HOME` from environment
  - then common paths (`%USERPROFILE%\source\agent-kit`,
    `%USERPROFILE%\sources\agent-kit`, `%USERPROFILE%\dev\agent-kit`,
    `C:\tools\agent-kit`, `D:\tools\agent-kit`)
  - if none match, re-run installer

Custom wrapper install location:

```text
AGENT_KIT_INSTALL_DIR=<custom-bin-dir>
```

Then re-run install script:

- `./bootstrap/install-auto-bootstrap.sh` (Linux / WSL)
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1` (Windows)

## Agent Command List

- Sample list in repo: `config/agents.list.sample`
- Real list used by installer:
  - `AGENT_KIT_AGENT_LIST` (if set)
  - else `config/agents.list` in `AGENT_KIT_HOME` when writable
  - else fallback `~/.config/agent-kit/agents.list`
- On first install, the real list is auto-initialized from the sample and
  filtered to commands currently detected on PATH (fallback: sample defaults).
- To enable extra commands, add them to the real list and re-run installer.

## Connect A Project Folder

There is no separate per-project registration file. A project folder is
considered connected once bootstrap has run successfully there and
`.agent-workflow/state.env` exists.

### Path A: Automatic via wrappers (recommended)

1. Ensure the project folder is a Git repository.
   If needed, run `git init` first.
2. Change into the project folder.
3. Run `codex`, `claude`, or `gemini`.
4. The wrapper triggers bootstrap automatically.
5. Confirm bootstrap files were created in that repository:
   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `MEMORY.md`, `SKILLS.md`
   - `workitems/`
   - `.agent-workflow/state.env`

### Path B: Manual bootstrap command

Useful for CI, migration steps, or when wrappers are not on PATH.

Linux / WSL:

```bash
AGENT_KIT_HOME=/abs/path/to/agent-kit \
/abs/path/to/agent-kit/bootstrap/bootstrap.sh \
  --project-root /abs/path/to/project \
  --agent codex
```

Windows PowerShell:

```powershell
$env:AGENT_KIT_HOME = "C:\abs\path\to\agent-kit"
powershell -NoProfile -File C:\abs\path\to\agent-kit\bootstrap\bootstrap.ps1 `
  --project-root C:\abs\path\to\project `
  --agent codex
```

## Windows Link Behavior

On Windows, bootstrap tries workflow file setup in this order:

1. Symbolic link
2. Hardlink (only if `agent-kit` and target repo are on the same drive)
3. Regular file copy fallback (default)

This means bootstrap still works even without symlink permissions.

If copy fallback is used:

- bootstrap is still functional for daily work
- later changes to `profiles/*.md` or `SKILLS.md` in `agent-kit` do not
  auto-update already copied project files
- run bootstrap again with `--force` to refresh copied files
- optional: set `AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS` to auto-refresh selected
  projects with `--force` (primarily useful for Windows projects using copy
  fallback)

To disable copy fallback and fail fast instead, set:

```text
AGENT_KIT_ALLOW_COPY_FALLBACK=0
```

## Troubleshooting

- Strict isolation block:
  If bootstrap reports unmanaged existing workflow files, read
  [Migration and rollback](docs/migration.md) and use a controlled migration.
- Wrapper cannot find real command:
  Set `AGENT_KIT_REAL_<AGENT_NAME>` (uppercased, non-alnum as `_`) to the real
  executable path. Example: `AGENT_KIT_REAL_CODEX`.
- Disable auto-bootstrap once:
  Run command with `AGENT_KIT_AUTOBOOTSTRAP=0`.
- Windows symlink permission issue:
  Enable Windows Developer Mode or run an elevated shell if you want true
  symlinks instead of copy fallback.

## Configuration

- `AGENT_KIT_HOME`: path to this repository
- `AGENT_KIT_AGENT_LIST`: explicit path to agent command list file
- `AGENT_KIT_AUTOBOOTSTRAP=0`: disable auto-bootstrap for one command
- `AGENT_KIT_AUTOBOOTSTRAP_FORCE_ROOTS`: project root list that should auto-refresh with `--force` (Windows `;`, Linux/WSL `:` separated; in practice mainly useful for Windows copy-fallback setups)
- `AGENT_KIT_STRICT_ISOLATION=1`: block mixed legacy state (default)
- `AGENT_KIT_ALLOW_COPY_FALLBACK=1`: allow copy fallback if links are not possible
- `AGENT_KIT_REAL_<AGENT_NAME>`: explicit real binary path override per command

Optional path-prefix profile mapping:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

File: `config/project-map.tsv`  
Format: `<absolute-path-prefix><TAB><profile-name>`

## Command Reference

- `./bootstrap/bootstrap.sh`: bootstrap current repo or `--project-root`
- `./bootstrap/bootstrap-all.sh`: bootstrap all repos under roots
- `./bootstrap/install-auto-bootstrap.sh`: install Bash wrappers
- `powershell -NoProfile -File .\bootstrap\bootstrap.ps1`: Windows bootstrap
- `powershell -NoProfile -File .\bootstrap\bootstrap-all.ps1`: Windows bulk bootstrap
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1`: Windows wrapper install
- `./scripts/ci-smoke.sh`: Bash smoke checks
- `powershell -NoProfile -File .\scripts\ci-smoke.ps1`: PowerShell smoke checks

## Documentation Map

- [Migration and rollback](docs/migration.md) ([DE](docs/migration.de.md))
- [Release process](docs/release.md) ([DE](docs/release.de.md))
- [Changelog](CHANGELOG.md)
- [License](LICENSE)
