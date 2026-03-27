# Skills Overview

This is a generic workflow entrypoint. Domain-specific skills can be layered on top
via project profiles.

## Suggested sequence

1. requirements-scoping
2. implementation
3. validation
4. release

## Workflow Hint: Community UI Components

Use this mini-flow when you source components from community libraries (for example 21st.dev):

1. define target slot and acceptance criteria
2. shortlist 2-5 candidates in the same category
3. verify license/usage rights before copy
4. integrate minimal code and map styles to local tokens
5. run a11y + responsive checks, then lint/type/test/build

## Commit Rules (all projects)

- NO signatures like "Co-Authored-By: Claude" or "Generated with Claude Code"

## AI CLI Check

```bash
bash --login -lc '
for c in claude gemini codex opencode aider; do
  if command -v "$c" >/dev/null 2>&1; then
    printf "%-8s -> %s | " "$c" "$(command -v "$c")"
    "$c" --version 2>/dev/null | head -n 1 || echo "version: n/a"
  else
    echo "$c -> not found"
  fi
done
'
```

## Playwright Testing (yWeb / Web UI)

```
# Desktop: http://localhost:31344/
# Mobile: Responsive Mode im Browser-DevTools
# Immer beide Ansichten testen bei UI-Änderungen
```

## agent-kit Sync

```bash
cd <agent-kit-root>
git add -A
git commit -m "chore: <was wurde aktualisiert>"
git push
```

## Wichtige Pfade (agent-kit Struktur)

```
agent-kit/
  profiles/             <- Projekt-Profile (CLAUDE.md Quelle)
  memory/               <- Shared Memory pro Projekt
  docs/                 <- Kontext-Docs pro Domaene
  workitems/            <- Cross-Repo Workitems
  todos/                <- TODO-Listen nach Bereich
  logs/                 <- Debug-Logs
  archive/              <- Veraltete Versionen
  templates/            <- Vorlagen fuer Workitems etc.
  bootstrap/            <- Bootstrap-Scripts
  SKILLS.md             <- Dieses File (Workflows)
```
