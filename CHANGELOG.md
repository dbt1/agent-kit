# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic
Versioning.

## [Unreleased]

### Added
- Initial bootstrap system for `claude`, `codex`, and `gemini`
- Strict isolation mode to prevent mixed legacy/new link states
- Profile-based project context wiring
- Workitem template bootstrap (`workitems/INDEX.md`, `template.md`)
- Optional project map config (`config/project-map.tsv.example`)
- CI workflow for shell syntax and smoke checks
- Migration/rollback documentation for existing repositories

### Changed
- Bootstrap now defers cleanly in non-Git directories and retries automatically
  after `git init` on the next wrapped agent call
- `--project-root` detection now uses `git -C <path> rev-parse --show-toplevel`
  for more robust Git root resolution

## [0.1.0] - 2026-03-13

### Added
- First public baseline of `agent-kit` core
