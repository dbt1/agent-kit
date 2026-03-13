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
LOG_SMOKE="$(mktemp)"
LOG_STRICT="$(mktemp)"
trap 'rm -rf "$TMP_REPO" "$TMP_BLOCK" "$LOG_SMOKE" "$LOG_STRICT"' EXIT

git -C "$TMP_REPO" init -q

if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 \
  ./bootstrap/bootstrap.sh --project-root "$TMP_REPO" >"$LOG_SMOKE" 2>&1; then
  echo "bootstrap smoke failed" >&2
  cat "$LOG_SMOKE" >&2
  exit 1
fi

check_path() {
  local p="$1"
  if [ ! -e "$TMP_REPO/$p" ]; then
    echo "expected path missing after bootstrap: $p" >&2
    echo "--- bootstrap log ---" >&2
    cat "$LOG_SMOKE" >&2
    echo "--- repo tree ---" >&2
    find "$TMP_REPO" -maxdepth 3 -print >&2
    exit 1
  fi
}

for p in \
  AGENTS.md \
  CLAUDE.md \
  GEMINI.md \
  MEMORY.md \
  SKILLS.md \
  workitems/INDEX.md \
  workitems/template.md \
  .agent-workflow/state.env; do
  check_path "$p"
done

# 3) Strict isolation block test
git -C "$TMP_BLOCK" init -q
echo "legacy" > "$TMP_BLOCK/AGENTS.md"

if AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 \
  ./bootstrap/bootstrap.sh --project-root "$TMP_BLOCK" >"$LOG_STRICT" 2>&1; then
  echo "strict isolation expected to block but command succeeded" >&2
  cat "$LOG_STRICT" >&2
  exit 1
fi

if ! grep -Eq "strict isolation|unmanaged existing" "$LOG_STRICT"; then
  echo "strict isolation failure message missing" >&2
  cat "$LOG_STRICT" >&2
  exit 1
fi

echo "ci-smoke: ok"
