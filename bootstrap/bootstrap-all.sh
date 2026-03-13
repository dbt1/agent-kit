#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap.sh"
ROOTS="${AGENT_KIT_PROJECT_ROOTS:-$HOME/sources:$HOME/source}"
DRY_RUN=0
FORCE=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] [--force] [--roots path1:path2]
USAGE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --roots)
        ROOTS="${2:-}"
        shift 2
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

main() {
  parse_args "$@"

  IFS=':' read -r -a root_list <<< "$ROOTS"
  for root in "${root_list[@]}"; do
    [ -d "$root" ] || continue

    while IFS= read -r -d '' project; do
      if [ -d "$project/.git" ] || [ -f "$project/.git" ]; then
        args=(--project-root "$project")
        [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)
        [ "$FORCE" -eq 1 ] && args+=(--force)
        "$BOOTSTRAP_SCRIPT" "${args[@]}"
      fi
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0)
  done
}

main "$@"
