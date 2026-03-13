#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

# 1) Syntax checks
bash -n bin/agent-wrapper
bash -n bootstrap/bootstrap.sh
bash -n bootstrap/bootstrap-all.sh
bash -n bootstrap/install-auto-bootstrap.sh

# 2) Bootstrap smoke test in clean repo
TMP_REPO="$(mktemp -d)"
TMP_BLOCK="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO" "$TMP_BLOCK"' EXIT

git -C "$TMP_REPO" init -q

AGENT_KIT_HOME="$ROOT_DIR" ./bootstrap/bootstrap.sh --project-root "$TMP_REPO" >/tmp/agent-kit-smoke.log

for p in \
  AGENTS.md \
  CLAUDE.md \
  GEMINI.md \
  MEMORY.md \
  SKILLS.md \
  workitems/INDEX.md \
  workitems/template.md \
  .agent-workflow/state.env; do
  test -e "$TMP_REPO/$p"
done

# 3) Strict isolation block test
git -C "$TMP_BLOCK" init -q
echo "legacy" > "$TMP_BLOCK/AGENTS.md"

if AGENT_KIT_HOME="$ROOT_DIR" ./bootstrap/bootstrap.sh --project-root "$TMP_BLOCK" >/tmp/agent-kit-strict.log 2>&1; then
  echo "strict isolation expected to block but command succeeded" >&2
  exit 1
fi

if ! grep -q "strict isolation" /tmp/agent-kit-strict.log; then
  echo "strict isolation failure message missing" >&2
  exit 1
fi

echo "ci-smoke: ok"
