#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_KIT_HOME="${AGENT_KIT_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BOOTSTRAP_VERSION="2026-03-23-core-v2"

DRY_RUN=0
FORCE=0
QUIET=0
NO_MCP=0
PROJECT_ROOT=""
AGENT_NAME=""
STRICT_ISOLATION="${AGENT_KIT_STRICT_ISOLATION:-1}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Options:
  --project-root <path>  Bootstrap this repository root directly
  --agent <name>         Agent command name
  --profile <name>       Force profile name
  --dry-run              Show planned changes only
  --force                Override marker and replace existing symlinks
  --quiet                Minimal output
  --no-strict            Disable strict isolation checks
  --no-mcp               Skip MCP server propagation via ruler
  -h, --help             Show help
USAGE
}

log() {
  if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$*"
  fi
}

log_err() {
  if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$*" >&2
  fi
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $*"
  else
    eval "$@"
  fi
}

ensure_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    run_cmd "mkdir -p \"$dir\""
  fi
}

safe_symlink() {
  local target="$1"
  local link="$2"
  ensure_dir "$(dirname "$link")"

  if [ -L "$link" ]; then
    local current
    current="$(readlink "$link")"
    if [ "$current" = "$target" ]; then
      return 0
    fi
    if [ "$FORCE" -eq 1 ]; then
      run_cmd "ln -sfn \"$target\" \"$link\""
    else
      log "[warn] keep existing symlink (use --force to replace): $link -> $current"
    fi
    return 0
  fi

  if [ -e "$link" ]; then
    log "[warn] keep existing regular file: $link"
    return 0
  fi

  run_cmd "ln -s \"$target\" \"$link\""
}

copy_if_missing() {
  local src="$1"
  local dst="$2"
  ensure_dir "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    return 0
  fi
  run_cmd "cp \"$src\" \"$dst\""
}

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '_'
}

detect_project_root() {
  local probe
  if [ -n "$PROJECT_ROOT" ]; then
    if [ ! -d "$PROJECT_ROOT" ]; then
      log_err "[warn] --project-root is not a directory: $PROJECT_ROOT"
      return 1
    fi
    probe="$PROJECT_ROOT"
  else
    probe="$PWD"
  fi

  git -C "$probe" rev-parse --show-toplevel 2>/dev/null || return 1
}

FORCED_PROFILE=""

read_map_profile() {
  local project="$1"
  local map_file="$AGENT_KIT_HOME/config/project-map.tsv"

  if [ ! -f "$map_file" ]; then
    return 1
  fi

  awk -v project="$project" '
    BEGIN { best=""; bestlen=-1 }
    $0 ~ /^#/ || NF < 2 { next }
    {
      prefix=$1
      profile=$2
      if (index(project, prefix) == 1) {
        if (length(prefix) > bestlen) {
          best=profile
          bestlen=length(prefix)
        }
      }
    }
    END {
      if (bestlen >= 0) {
        print best
        exit 0
      }
      exit 1
    }
  ' "$map_file"
}

detect_profile() {
  local project="$1"

  if [ -n "$FORCED_PROFILE" ]; then
    printf '%s\n' "$FORCED_PROFILE"
    return 0
  fi

  if [ -f "$project/.agent-workflow/profile" ]; then
    local p
    p="$(tr -d '[:space:]' < "$project/.agent-workflow/profile")"
    if [ -n "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  fi

  if p_map="$(read_map_profile "$project" 2>/dev/null)"; then
    if [ -n "$p_map" ]; then
      printf '%s\n' "$p_map"
      return 0
    fi
  fi

  printf '%s\n' "generic"
}

is_managed_symlink() {
  local path="$1"
  if [ ! -L "$path" ]; then
    return 1
  fi
  local target
  target="$(readlink "$path")"
  case "$target" in
    "$AGENT_KIT_HOME"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

strict_isolation_check() {
  local project="$1"
  [ "$STRICT_ISOLATION" = "1" ] || return 0
  [ "$FORCE" -eq 0 ] || return 0

  local f
  for f in AGENTS.md CLAUDE.md GEMINI.md MEMORY.md SKILLS.md; do
    if [ -e "$project/$f" ] && ! is_managed_symlink "$project/$f"; then
      log "[block] strict isolation: unmanaged existing file/symlink at $project/$f"
      log "[hint] use --force for explicit replacement or migrate in a controlled step"
      return 1
    fi
  done

  return 0
}

write_memory_file() {
  local memory_file="$1"
  local project="$2"
  local profile="$3"
  if [ -e "$memory_file" ]; then
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] create memory file $memory_file"
    return 0
  fi
  cat > "$memory_file" <<MEM
# $(basename "$project")_MEMORY

## Project
- Root: $project
- Profile: $profile

## Notes
- Add persistent project-specific learnings here.
- Keep gotchas and validated command snippets concise.
MEM
}

write_state_file() {
  local state_file="$1"
  local project="$2"
  local profile="$3"
  local memory_file="$4"
  local now
  now="$(date -Iseconds)"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] write $state_file"
    return 0
  fi

  cat > "$state_file" <<STATE
MODE=v2
BOOTSTRAP_VERSION=$BOOTSTRAP_VERSION
BOOTSTRAPPED_AT=$now
AGENT_NAME=${AGENT_NAME:-unknown}
PROJECT_ROOT=$project
PROFILE=$profile
AGENT_KIT_HOME=$AGENT_KIT_HOME
MEMORY_FILE=$memory_file
STATE
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project-root)
        PROJECT_ROOT="${2:-}"
        shift 2
        ;;
      --agent)
        AGENT_NAME="${2:-}"
        shift 2
        ;;
      --profile)
        FORCED_PROFILE="${2:-}"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --quiet)
        QUIET=1
        shift
        ;;
      --no-strict)
        STRICT_ISOLATION=0
        shift
        ;;
      --no-mcp)
        NO_MCP=1
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

main() {
  parse_args "$@"

  local project
  if ! project="$(detect_project_root)"; then
    if [ "$QUIET" -eq 0 ]; then
      if [ -n "$PROJECT_ROOT" ]; then
        log "[skip] bootstrap deferred: '$PROJECT_ROOT' is not a git repository yet"
      else
        log "[skip] bootstrap deferred: current directory is not in a git repository"
      fi
      log "[hint] bootstrap will run automatically on the next wrapped agent call after 'git init'"
    fi
    exit 0
  fi

  if ! strict_isolation_check "$project"; then
    exit 2
  fi

  local marker_dir state_file
  marker_dir="$project/.agent-workflow"
  state_file="$marker_dir/state.env"

  if [ "$FORCE" -eq 0 ] && [ -f "$state_file" ]; then
    if grep -q "^BOOTSTRAP_VERSION=$BOOTSTRAP_VERSION$" "$state_file"; then
      [ "$QUIET" -eq 1 ] || log "[ok] already bootstrapped: $project"
      exit 0
    fi
  fi

  local profile profile_file
  profile="$(detect_profile "$project")"
  profile_file="$AGENT_KIT_HOME/profiles/$profile.md"
  if [ ! -f "$profile_file" ]; then
    profile="generic"
    profile_file="$AGENT_KIT_HOME/profiles/generic.md"
  fi

  local project_name memory_file
  project_name="$(sanitize_name "$(basename "$project")")"
  memory_file="$AGENT_KIT_HOME/memory/${project_name}_MEMORY.md"

  log "[info] project: $project"
  log "[info] profile: $profile"

  ensure_dir "$marker_dir"
  ensure_dir "$AGENT_KIT_HOME/memory"

  write_memory_file "$memory_file" "$project" "$profile"

  safe_symlink "$profile_file" "$project/AGENTS.md"
  safe_symlink "$profile_file" "$project/CLAUDE.md"
  safe_symlink "$profile_file" "$project/GEMINI.md"
  safe_symlink "$memory_file" "$project/MEMORY.md"
  safe_symlink "$AGENT_KIT_HOME/SKILLS.md" "$project/SKILLS.md"

  copy_if_missing "$AGENT_KIT_HOME/templates/workitems/INDEX.md" "$project/workitems/INDEX.md"
  copy_if_missing "$AGENT_KIT_HOME/templates/workitems/template.md" "$project/workitems/template.md"

  write_state_file "$state_file" "$project" "$profile" "$memory_file"

  # --- MCP propagation via ruler ---
  propagate_mcp "$project"

  log "[done] bootstrap complete"
}

propagate_mcp() {
  local project="$1"
  local ruler_source="$AGENT_KIT_HOME/.ruler"

  if [ "$NO_MCP" -eq 1 ]; then
    log "[skip] MCP propagation disabled (--no-mcp)"
    return 0
  fi

  if [ ! -f "$ruler_source/ruler.toml" ]; then
    log "[skip] no .ruler/ruler.toml found in agent-kit"
    return 0
  fi

  local ruler_bin
  ruler_bin="$(command -v ruler 2>/dev/null || true)"
  if [ -z "$ruler_bin" ]; then
    # try common user-local npm path
    if [ -x "$HOME/.npm-global/bin/ruler" ]; then
      ruler_bin="$HOME/.npm-global/bin/ruler"
    else
      log "[skip] ruler not found in PATH — install with: npm install -g @intellectronica/ruler"
      return 0
    fi
  fi

  # symlink .ruler/ into project
  safe_symlink "$ruler_source" "$project/.ruler"

  # interactive mode: show servers and ask for confirmation
  # quiet/force mode (e.g. via wrapper): apply automatically with info line
  local server_names
  server_names="$(grep -oP '^\[mcp_servers\.\K[^]]+' "$ruler_source/ruler.toml" | paste -sd',' | sed 's/,/, /g')"

  if [ "$QUIET" -eq 0 ] && [ "$FORCE" -eq 0 ] && [ -t 0 ]; then
    log ""
    log "[mcp] The following MCP servers will be configured:"
    grep -E '^\[mcp_servers\.' "$ruler_source/ruler.toml" | sed 's/\[mcp_servers\.\(.*\)\]/  - \1/' || true
    log ""
    printf "Apply MCP server configs to this project? [y/N] "
    read -r answer
    case "$answer" in
      [yYjJ]*)
        ;;
      *)
        log "[skip] MCP propagation declined by user"
        return 0
        ;;
    esac
  else
    # always show a brief info, even in quiet mode
    printf '%s\n' "[mcp] configuring servers: $server_names"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] ruler apply --mcp --no-skills --project-root \"$project\""
    return 0
  fi

  # determine which agents to configure from agents.list
  local agents_list_file="$AGENT_KIT_HOME/config/agents.list"
  local ruler_agents="claude,codex,gemini-cli,copilot"
  if [ -f "$agents_list_file" ]; then
    local parsed
    parsed="$(grep -v '^\s*#' "$agents_list_file" | grep -v '^\s*$' | tr '\n' ',' | sed 's/,$//')"
    if [ -n "$parsed" ]; then
      ruler_agents="$parsed"
    fi
  fi

  log "[mcp] running ruler apply ..."
  (cd "$project" && "$ruler_bin" apply --mcp --no-skills --no-gitignore --no-backup --agents "$ruler_agents" 2>&1) | while IFS= read -r line; do
    log "[ruler] $line"
  done
}

main "$@"
