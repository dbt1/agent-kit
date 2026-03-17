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
TMP_DEFER="$(mktemp -d)"
TMP_INSTALL="$(mktemp -d)"
TMP_AGENT_LIST_DIR="$(mktemp -d)"
TMP_AGENT_LIST="$TMP_AGENT_LIST_DIR/agents.list"
LOG_SMOKE="$(mktemp)"
LOG_STRICT="$(mktemp)"
LOG_DEFER="$(mktemp)"
LOG_INSTALL="$(mktemp)"
trap 'rm -rf "$TMP_REPO" "$TMP_BLOCK" "$TMP_DEFER" "$TMP_INSTALL" "$TMP_AGENT_LIST_DIR" "$LOG_SMOKE" "$LOG_STRICT" "$LOG_DEFER" "$LOG_INSTALL"' EXIT

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

# 3) Installer initializes agent list and installs wrappers from that list
if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_INSTALL_DIR="$TMP_INSTALL" AGENT_KIT_AGENT_LIST="$TMP_AGENT_LIST" \
  ./bootstrap/install-auto-bootstrap.sh >"$LOG_INSTALL" 2>&1; then
  echo "install-auto-bootstrap smoke failed" >&2
  cat "$LOG_INSTALL" >&2
  exit 1
fi

if [ ! -s "$TMP_AGENT_LIST" ]; then
  echo "expected generated agent list missing: $TMP_AGENT_LIST" >&2
  cat "$LOG_INSTALL" >&2
  exit 1
fi

mapfile -t configured_agents < <(awk '
  {
    line=$0
    sub(/\r$/, "", line)
    sub(/[[:space:]]*#.*/, "", line)
    gsub(/^[[:space:]]+/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    if (line != "") print line
  }
' "$TMP_AGENT_LIST")

if [ "${#configured_agents[@]}" -eq 0 ]; then
  echo "generated agent list does not contain usable entries" >&2
  cat "$TMP_AGENT_LIST" >&2
  cat "$LOG_INSTALL" >&2
  exit 1
fi

for cmd in "${configured_agents[@]}"; do
  if [ ! -e "$TMP_INSTALL/$cmd" ]; then
    echo "expected wrapper missing for configured agent '$cmd'" >&2
    echo "--- install log ---" >&2
    cat "$LOG_INSTALL" >&2
    echo "--- install dir ---" >&2
    find "$TMP_INSTALL" -maxdepth 2 -print >&2
    exit 1
  fi
done

# 4) Deferred bootstrap if folder is not a git repo yet
if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 \
  ./bootstrap/bootstrap.sh --project-root "$TMP_DEFER" >"$LOG_DEFER" 2>&1; then
  echo "deferred bootstrap should not fail in non-git directory" >&2
  cat "$LOG_DEFER" >&2
  exit 1
fi

if [ -e "$TMP_DEFER/.agent-workflow/state.env" ]; then
  echo "state file should not exist before git init" >&2
  find "$TMP_DEFER" -maxdepth 3 -print >&2
  exit 1
fi

if ! grep -Eq "bootstrap deferred|not in a git repository" "$LOG_DEFER"; then
  echo "expected deferred bootstrap message missing" >&2
  cat "$LOG_DEFER" >&2
  exit 1
fi

git -C "$TMP_DEFER" init -q
if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 \
  ./bootstrap/bootstrap.sh --project-root "$TMP_DEFER" >"$LOG_DEFER" 2>&1; then
  echo "bootstrap after git init failed" >&2
  cat "$LOG_DEFER" >&2
  exit 1
fi

if [ ! -e "$TMP_DEFER/.agent-workflow/state.env" ]; then
  echo "state file missing after git init bootstrap" >&2
  cat "$LOG_DEFER" >&2
  find "$TMP_DEFER" -maxdepth 3 -print >&2
  exit 1
fi

# 5) Strict isolation block test
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
