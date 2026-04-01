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
TMP_HOST_MAP_DIR="$ROOT_DIR/config/project-map"
TMP_HOST_MAP="$TMP_HOST_MAP_DIR/smoke-host.tsv"
TMP_HOST_MAP_OTHER="$TMP_HOST_MAP_DIR/other-host.tsv"
TMP_MEMORY_ROOT="$ROOT_DIR/memory/projects/smoke-project"
LOG_SMOKE="$(mktemp)"
LOG_STRICT="$(mktemp)"
LOG_DEFER="$(mktemp)"
LOG_INSTALL="$(mktemp)"
trap 'rm -rf "$TMP_REPO" "$TMP_BLOCK" "$TMP_DEFER" "$TMP_INSTALL" "$TMP_AGENT_LIST_DIR" "$TMP_MEMORY_ROOT" "$LOG_SMOKE" "$LOG_STRICT" "$LOG_DEFER" "$LOG_INSTALL"; rm -f "$TMP_HOST_MAP" "$TMP_HOST_MAP_OTHER"; rmdir "$TMP_HOST_MAP_DIR" 2>/dev/null || true' EXIT

git -C "$TMP_REPO" init -q
mkdir -p "$TMP_HOST_MAP_DIR"
printf '%s\tgeneric\tsmoke-project\n' "$TMP_REPO" > "$TMP_HOST_MAP"
printf '%s\tgeneric\tsmoke-project\n' "$TMP_REPO" > "$TMP_HOST_MAP_OTHER"

if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 AGENT_KIT_HOST_ID=smoke-host \
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

for p in \
  "$ROOT_DIR/memory/projects/smoke-project/shared.md" \
  "$ROOT_DIR/memory/projects/smoke-project/hosts/smoke-host.md" \
  "$ROOT_DIR/memory/projects/smoke-project/index/smoke-host.md"; do
  if [ ! -e "$p" ]; then
    echo "expected host-aware memory path missing: $p" >&2
    cat "$LOG_SMOKE" >&2
    exit 1
  fi
done

if [ "$(readlink "$TMP_REPO/MEMORY.md")" != "$ROOT_DIR/memory/projects/smoke-project/index/smoke-host.md" ]; then
  echo "unexpected MEMORY.md target" >&2
  readlink "$TMP_REPO/MEMORY.md" >&2 || true
  exit 1
fi

if ! grep -q '^HOST_ID=smoke-host$' "$TMP_REPO/.agent-workflow/state.env"; then
  echo "HOST_ID missing in state.env" >&2
  cat "$TMP_REPO/.agent-workflow/state.env" >&2
  exit 1
fi

if ! grep -q '^PROJECT_ID=smoke-project$' "$TMP_REPO/.agent-workflow/state.env"; then
  echo "PROJECT_ID missing in state.env" >&2
  cat "$TMP_REPO/.agent-workflow/state.env" >&2
  exit 1
fi

if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 AGENT_KIT_HOST_ID=other-host \
  ./bootstrap/bootstrap.sh --project-root "$TMP_REPO" --force >"$LOG_SMOKE" 2>&1; then
  echo "second-host bootstrap smoke failed" >&2
  cat "$LOG_SMOKE" >&2
  exit 1
fi

if [ ! -e "$ROOT_DIR/memory/projects/smoke-project/hosts/other-host.md" ] || \
   [ ! -e "$ROOT_DIR/memory/projects/smoke-project/index/other-host.md" ]; then
  echo "second host memory files missing" >&2
  find "$ROOT_DIR/memory/projects/smoke-project" -maxdepth 3 -print >&2
  exit 1
fi

if ! grep -q 'smoke-host' "$ROOT_DIR/memory/projects/smoke-project/index/other-host.md"; then
  echo "other-host index does not reference the first host" >&2
  cat "$ROOT_DIR/memory/projects/smoke-project/index/other-host.md" >&2
  exit 1
fi

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
if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 AGENT_KIT_HOST_ID=smoke-host \
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
if ! AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 AGENT_KIT_HOST_ID=smoke-host \
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

if AGENT_KIT_HOME="$ROOT_DIR" AGENT_KIT_STRICT_ISOLATION=1 AGENT_KIT_HOST_ID=smoke-host \
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
