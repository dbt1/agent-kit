#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_KIT_HOME="${AGENT_KIT_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WRAPPER_SOURCE="$AGENT_KIT_HOME/bin/agent-wrapper"
INSTALL_DIR="${AGENT_KIT_INSTALL_DIR:-$HOME/.local/share/agent-kit/bin}"
AGENT_LIST_SAMPLE="$AGENT_KIT_HOME/config/agents.list.sample"
DEFAULT_AGENT_LIST_FILE="$AGENT_KIT_HOME/config/agents.list"
FALLBACK_AGENT_LIST_FILE="$HOME/.config/agent-kit/agents.list"
AGENT_LIST_FILE=""
ACTIVATE=0
AGENTS=()

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--activate-bashrc]

Installs wrappers for configured agent commands into:
  $INSTALL_DIR

Agent list file (first match wins):
  AGENT_KIT_AGENT_LIST (if set)
  $DEFAULT_AGENT_LIST_FILE (if writable)
  $FALLBACK_AGENT_LIST_FILE (fallback)
USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --activate-bashrc)
        ACTIVATE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

is_valid_agent_name() {
  case "$1" in
    ""|*[!A-Za-z0-9._+-]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

emit_agents_from_file() {
  local file="$1"
  awk '
    {
      line=$0
      sub(/\r$/, "", line)
      sub(/[[:space:]]*#.*/, "", line)
      gsub(/^[[:space:]]+/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      if (line != "") {
        print line
      }
    }
  ' "$file"
}

normalize_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    (cd "$dir" && pwd -P)
    return 0
  fi
  local parent base
  parent="$(dirname "$dir")"
  base="$(basename "$dir")"
  if [ ! -d "$parent" ]; then
    return 1
  fi
  printf '%s/%s\n' "$(cd "$parent" && pwd -P)" "$base"
}

resolve_real_cmd() {
  local cmd="$1"
  local wrapper_real install_real candidate candidate_real
  wrapper_real="$(readlink -f "$WRAPPER_SOURCE" 2>/dev/null || realpath "$WRAPPER_SOURCE" 2>/dev/null || printf '%s' "$WRAPPER_SOURCE")"
  install_real="$(normalize_dir "$INSTALL_DIR" 2>/dev/null || printf '%s' "$INSTALL_DIR")"

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate_real="$(readlink -f "$candidate" 2>/dev/null || realpath "$candidate" 2>/dev/null || printf '%s' "$candidate")"
    if [ -n "$install_real" ]; then
      case "$candidate_real" in
        "$install_real"/*)
          continue
          ;;
      esac
    fi
    if [ "$candidate_real" = "$wrapper_real" ]; then
      continue
    fi
    printf '%s\n' "$candidate"
    return 0
  done < <(which -a "$cmd" 2>/dev/null | awk '!seen[$0]++')

  return 1
}

select_agent_list_file() {
  local preferred preferred_dir
  if [ -n "${AGENT_KIT_AGENT_LIST:-}" ]; then
    AGENT_LIST_FILE="$AGENT_KIT_AGENT_LIST"
    return 0
  fi

  preferred="$DEFAULT_AGENT_LIST_FILE"
  preferred_dir="$(dirname "$preferred")"
  if [ -f "$preferred" ]; then
    AGENT_LIST_FILE="$preferred"
    return 0
  fi

  mkdir -p "$preferred_dir" 2>/dev/null || true
  if [ -w "$preferred_dir" ]; then
    AGENT_LIST_FILE="$preferred"
    return 0
  fi

  AGENT_LIST_FILE="$FALLBACK_AGENT_LIST_FILE"
}

initialize_agent_list_file() {
  local candidate dir cmd now
  local -a candidates=()
  local -a detected=()
  local -a selected=()

  if [ -f "$AGENT_LIST_FILE" ]; then
    return 0
  fi

  if [ -f "$AGENT_LIST_SAMPLE" ]; then
    while IFS= read -r candidate; do
      if ! is_valid_agent_name "$candidate"; then
        echo "[warn] ignoring invalid agent name in sample: $candidate" >&2
        continue
      fi
      if array_contains "$candidate" "${candidates[@]}"; then
        continue
      fi
      candidates+=("$candidate")
    done < <(emit_agents_from_file "$AGENT_LIST_SAMPLE")
  fi

  if [ "${#candidates[@]}" -eq 0 ]; then
    candidates=(codex claude gemini)
  fi

  for cmd in "${candidates[@]}"; do
    if resolve_real_cmd "$cmd" >/dev/null; then
      detected+=("$cmd")
    fi
  done

  if [ "${#detected[@]}" -gt 0 ]; then
    selected=("${detected[@]}")
  else
    selected=("${candidates[@]}")
  fi

  dir="$(dirname "$AGENT_LIST_FILE")"
  mkdir -p "$dir"
  now="$(date -Iseconds)"
  {
    echo "# agent-kit local agent command list"
    echo "# generated: $now"
    echo "# one command name per line"
    echo
    for cmd in "${selected[@]}"; do
      echo "$cmd"
    done
  } > "$AGENT_LIST_FILE"

  if [ "${#detected[@]}" -gt 0 ]; then
    echo "initialized agent list: $AGENT_LIST_FILE (detected: ${selected[*]})"
  else
    echo "initialized agent list: $AGENT_LIST_FILE (no command detected, using sample entries)"
  fi
}

load_configured_agents() {
  local candidate
  AGENTS=()

  if [ ! -f "$AGENT_LIST_FILE" ]; then
    echo "missing agent list: $AGENT_LIST_FILE" >&2
    return 1
  fi

  while IFS= read -r candidate; do
    if ! is_valid_agent_name "$candidate"; then
      echo "[warn] ignoring invalid agent name in $AGENT_LIST_FILE: $candidate" >&2
      continue
    fi
    if array_contains "$candidate" "${AGENTS[@]}"; then
      continue
    fi
    AGENTS+=("$candidate")
  done < <(emit_agents_from_file "$AGENT_LIST_FILE")

  if [ "${#AGENTS[@]}" -eq 0 ]; then
    echo "no valid agent commands found in $AGENT_LIST_FILE" >&2
    return 1
  fi
}

install_wrappers() {
  local cmd
  mkdir -p "$INSTALL_DIR"
  for cmd in "${AGENTS[@]}"; do
    ln -sfn "$WRAPPER_SOURCE" "$INSTALL_DIR/$cmd"
    echo "linked: $INSTALL_DIR/$cmd -> $WRAPPER_SOURCE"
  done
}

activate_bashrc() {
  local bashrc="$HOME/.bashrc"
  local start="# >>> agent-kit auto-bootstrap >>>"
  local end="# <<< agent-kit auto-bootstrap <<<"

  if [ -f "$bashrc" ] && grep -Fq "$start" "$bashrc"; then
    echo "~/.bashrc already contains agent-kit block"
    return 0
  fi

  {
    echo "$start"
    echo "if [ -d \"$INSTALL_DIR\" ] && [[ \":\$PATH:\" != *\":$INSTALL_DIR:\"* ]]; then"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo "fi"
    echo "$end"
  } >> "$bashrc"

  echo "added PATH block to ~/.bashrc"
}

main() {
  parse_args "$@"
  select_agent_list_file
  initialize_agent_list_file
  load_configured_agents
  install_wrappers

  echo "agent list: $AGENT_LIST_FILE"

  if [ "$ACTIVATE" -eq 1 ]; then
    activate_bashrc
    echo "Run: source ~/.bashrc"
  else
    echo "To activate in current shell:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
  fi
}

main "$@"
