#!/usr/bin/env bash

set -euo pipefail

PROGRAM_NAME="$(basename "$0")"
CONFIG_FILE="${CTASK_CONFIG:-${TASK_RUNNER_CONFIG:-}}"
LEGACY_CONFIG_FILE="${CODEX_TASK_CONFIG:-$HOME/.config/codex-interactive-mode/env.sh}"

if [[ -z "$CONFIG_FILE" && -f "$HOME/.config/ctask/env.sh" ]]; then
  CONFIG_FILE="$HOME/.config/ctask/env.sh"
elif [[ -z "$CONFIG_FILE" && -f "$HOME/.config/task-runner/env.sh" ]]; then
  CONFIG_FILE="$HOME/.config/task-runner/env.sh"
elif [[ -z "$CONFIG_FILE" && -f "$LEGACY_CONFIG_FILE" ]]; then
  CONFIG_FILE="$LEGACY_CONFIG_FILE"
fi

if [[ -n "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

TASK_NAME="${1:-}"
WORKDIR="${CTASK_WORKDIR:-${TASK_RUNNER_WORKDIR:-${CODEX_WORKDIR:-$HOME/WorkSpace}}}"
SOCKET_DIR="${CTASK_SOCKET_DIR:-${TASK_RUNNER_SOCKET_DIR:-${CODEX_SOCKET_DIR:-/tmp/ctask-tmux}}}"
SESSION_PREFIX="${CTASK_SESSION_PREFIX:-${TASK_RUNNER_SESSION_PREFIX:-${CODEX_SESSION_PREFIX:-ctask}}}"
ROUTE_FILE="${CTASK_ROUTES:-${TASK_RUNNER_ROUTES:-$HOME/.config/ctask/routes.conf}}"
ENABLE_BUILTIN_ROUTES="${CTASK_ENABLE_BUILTIN_ROUTES:-1}"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME <task-name>
  $PROGRAM_NAME --list

Environment:
  CTASK_CONFIG          Optional env file to source before starting
  CTASK_WORKDIR         Working directory for the tmux session
  CTASK_SOCKET_DIR      Directory that stores per-task tmux sockets
  CTASK_SESSION_PREFIX  Prefix for tmux session names
  CTASK_ROUTES          Optional route file with '<glob>=<command>' lines
  CTASK_ENABLE_BUILTIN_ROUTES
                       Enable built-in codex/gemini routes (default: 1)

Compatibility:
  TASK_RUNNER_* and CODEX_* environment variables still work for migration.
  If no ctask config exists, legacy task-runner and codex-interactive-mode env files are loaded.

Example:
  $PROGRAM_NAME codex
  $PROGRAM_NAME gemini
  $PROGRAM_NAME shell
  $PROGRAM_NAME --list
EOF
}

quote_path_dir_for_path() {
  local executable="$1"

  if [[ "$executable" == /* ]]; then
    printf 'export PATH=%q:"$PATH"\n' "$(dirname "$executable")"
  fi
}

build_debug_fallback() {
  cat <<'EOF'
status=$?

if [[ $status -ne 0 ]]; then
  printf '\nctask: startup command failed with exit status %s\n' "$status" >&2
  printf 'ctask: CTASK_WORKDIR=%q\n' "${CTASK_WORKDIR:-${TASK_RUNNER_WORKDIR:-${CODEX_WORKDIR:-}}}" >&2
  printf 'ctask: dropping into an interactive shell for debugging.\n' >&2
  exec bash
fi
EOF
}

route_command_from_file() {
  local line
  local pattern
  local command

  [[ -f "$ROUTE_FILE" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" && "${line:0:1}" != "#" ]] || continue
    [[ "$line" == *"="* ]] || continue

    pattern="${line%%=*}"
    command="${line#*=}"

    if [[ "$TASK_NAME" == $pattern ]]; then
      printf '%s\n' "$command"
      return 0
    fi
  done < "$ROUTE_FILE"

  return 1
}

route_builtin_command() {
  [[ "$ENABLE_BUILTIN_ROUTES" == "1" ]] || return 1

  case "$TASK_NAME" in
    danger|danger-*|codex-danger|codex-danger-*)
      printf 'codex --sandbox danger-full-access --ask-for-approval never\n'
      return 0
      ;;
    codex|codex-*)
      printf 'codex --full-auto\n'
      return 0
      ;;
    gemini-yolo|gemini-yolo-*)
      printf 'gemini --yolo\n'
      return 0
      ;;
    gemini|gemini-*)
      printf 'gemini\n'
      return 0
      ;;
  esac

  return 1
}

build_start_cmd() {
  local routed_cmd=""
  local task_executable=""

  if routed_cmd="$(route_command_from_file)"; then
    task_executable="${routed_cmd%% *}"
    quote_path_dir_for_path "$task_executable"
    printf 'eval %q\n' "$routed_cmd"
    build_debug_fallback
    return 0
  fi

  if routed_cmd="$(route_builtin_command)"; then
    task_executable="${routed_cmd%% *}"
    quote_path_dir_for_path "$task_executable"
    printf 'eval %q\n' "$routed_cmd"
    build_debug_fallback
    return 0
  fi

  printf 'exec bash\n'
}

session_exists() {
  local socket_path="$1"
  local session_name="$2"

  tmux -S "$socket_path" has-session -t "$session_name" 2>/dev/null
}

list_tasks() {
  local socket_path
  local task_name
  local session_name
  local status

  if [[ ! -d "$SOCKET_DIR" ]]; then
    echo "No task socket directory: $SOCKET_DIR"
    return 0
  fi

  shopt -s nullglob
  local sockets=("$SOCKET_DIR"/*.sock)
  shopt -u nullglob

  if [[ ${#sockets[@]} -eq 0 ]]; then
    echo "No tasks found in $SOCKET_DIR"
    return 0
  fi

  printf '%-24s %-8s %-32s %s\n' "TASK" "STATUS" "SESSION" "SOCKET"

  for socket_path in "${sockets[@]}"; do
    task_name="$(basename "${socket_path%.sock}")"
    session_name="${SESSION_PREFIX}-${task_name}"
    status="stale"

    if session_exists "$socket_path" "$session_name"; then
      status="active"
    fi

    printf '%-24s %-8s %-32s %s\n' "$task_name" "$status" "$session_name" "$socket_path"
  done
}

if [[ -z "$TASK_NAME" ]]; then
  usage
  exit 1
fi

if [[ "$TASK_NAME" == "-h" || "$TASK_NAME" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$TASK_NAME" == "-l" || "$TASK_NAME" == "--list" ]]; then
  list_tasks
  exit 0
fi

if [[ ! "$TASK_NAME" =~ ^[a-z]+(-[a-z]+)*$ ]]; then
  echo "Invalid task name: $TASK_NAME" >&2
  echo "Allowed format: lowercase letters and '-' only; '-' cannot be the first or last character." >&2
  exit 1
fi

if [[ ! -d "$WORKDIR" ]]; then
  echo "CTASK_WORKDIR does not exist or is not a directory: $WORKDIR" >&2
  exit 1
fi

mkdir -p "$SOCKET_DIR"
chmod 700 "$SOCKET_DIR"

SOCKET_PATH="$SOCKET_DIR/${TASK_NAME}.sock"
SESSION_NAME="${SESSION_PREFIX}-${TASK_NAME}"

if [[ -S "$SOCKET_PATH" ]] && ! session_exists "$SOCKET_PATH" "$SESSION_NAME"; then
  rm -f "$SOCKET_PATH"
fi

if ! session_exists "$SOCKET_PATH" "$SESSION_NAME"; then
  START_CMD="$(build_start_cmd)"

  tmux -S "$SOCKET_PATH" new-session -d -s "$SESSION_NAME" -c "$WORKDIR" bash -lc "$START_CMD"
fi

exec tmux -S "$SOCKET_PATH" attach -t "$SESSION_NAME"
