#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_KIT_HOME="${AGENT_KIT_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WRAPPER_SOURCE="$AGENT_KIT_HOME/bin/agent-wrapper"
INSTALL_DIR="${AGENT_KIT_INSTALL_DIR:-$HOME/.local/share/agent-kit/bin}"
ACTIVATE=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--activate-bashrc]

Installs wrappers for claude/codex/gemini into:
  $INSTALL_DIR
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

install_wrappers() {
  mkdir -p "$INSTALL_DIR"
  for cmd in claude codex gemini; do
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
  install_wrappers

  if [ "$ACTIVATE" -eq 1 ]; then
    activate_bashrc
    echo "Run: source ~/.bashrc"
  else
    echo "To activate in current shell:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
  fi
}

main "$@"
