# agent-kit

Language: [English](README.md) | [Deutsch](README.de.md)

Generic bootstrap kit for agent-driven repository workflows.

## What this does

On first `claude`, `codex`, or `gemini` call inside a Git repository, `agent-kit`
can automatically bootstrap a consistent workflow layout:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` (profile symlinks)
- `MEMORY.md` (project-specific memory symlink)
- `SKILLS.md` (skills overview symlink)
- `workitems/INDEX.md` and `workitems/template.md`
- `.agent-workflow/state.env` marker

## Design goals

- Strict isolation: avoid mixed legacy/new setups by default
- Idempotent execution
- Generic defaults (no domain lock-in)
- Optional profile mapping via config

## Quickstart

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

Then call `claude`, `codex`, or `gemini` inside any Git repo.

## Environment

- `AGENT_KIT_HOME`: absolute path to this repo (auto-resolved in wrapper)
- `AGENT_KIT_AUTOBOOTSTRAP=0`: disable auto-bootstrap for one command
- `AGENT_KIT_STRICT_ISOLATION=1`: block mixed legacy state (default)
- `AGENT_KIT_REAL_CLAUDE`, `AGENT_KIT_REAL_CODEX`, `AGENT_KIT_REAL_GEMINI`:
  explicit binary paths for wrappers

## Profile mapping

Optional path-prefix mappings can be defined in `config/project-map.tsv`:

```text
/home/user/sources/neutrino	custom-profile
/home/user/work	generic
```

Format: `<absolute-path-prefix><TAB><profile-name>`

## Commands

- `./bootstrap/bootstrap.sh` - bootstrap current repo or explicit `--project-root`
- `./bootstrap/bootstrap-all.sh` - bootstrap all repos under roots
- `./bootstrap/install-auto-bootstrap.sh` - install and activate wrappers
- `powershell -NoProfile -File .\bootstrap\bootstrap.ps1` - native Windows bootstrap
- `powershell -NoProfile -File .\bootstrap\bootstrap-all.ps1` - native Windows bulk bootstrap
- `powershell -NoProfile -File .\bootstrap\install-auto-bootstrap.ps1` - native Windows wrapper install
- `./scripts/ci-smoke.sh` - local syntax + smoke validation
- `powershell -NoProfile -File .\scripts\ci-smoke.ps1` - local Windows syntax + smoke validation

## Project status files

`state.env` is written to `.agent-workflow/` in each project and tracks
bootstrap version/profile/paths.

## Migration and release docs

- `docs/migration.md` - safe migration and rollback guidance
- `docs/release.md` - release process and versioning
- `CHANGELOG.md` - change history
- `LICENSE` - MIT
