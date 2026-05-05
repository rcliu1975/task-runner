#!/usr/bin/env bash

set -euo pipefail

TASK_NAME="${1:-}"
WORKDIR="${CODEX_WORKDIR:-$HOME/WorkSpace}"
SOCKET_DIR="${CODEX_SOCKET_DIR:-/tmp/codex-tmux}"
SESSION_PREFIX="${CODEX_SESSION_PREFIX:-codex}"
CODEX_CMD="${CODEX_CMD:-}"

usage() {
  cat <<'EOF'
Usage:
  codex-task.sh <task-name>
  codex-task.sh --list

Environment:
  CODEX_WORKDIR         Working directory for the tmux session
  CODEX_SOCKET_DIR      Directory that stores per-task tmux sockets
  CODEX_SESSION_PREFIX  Prefix for tmux session names
  CODEX_CMD             Command started inside tmux when creating a new task

Example:
  CODEX_CMD='codex' codex-task.sh review
  CODEX_CMD='opencode' codex-task.sh long-job
  codex-task.sh danger-maintenance
  codex-task.sh --list
EOF
}

build_start_cmd() {
  if [[ "$TASK_NAME" == "danger" || "$TASK_NAME" == danger-* || "$TASK_NAME" == codex-danger || "$TASK_NAME" == codex-danger-* ]]; then
    printf 'exec codex --sandbox danger-full-access --ask-for-approval never\n'
    return 0
  fi

  if [[ "$TASK_NAME" == "codex" || "$TASK_NAME" == codex-* ]]; then
    printf 'exec codex --full-auto\n'
    return 0
  fi

  if [[ "$TASK_NAME" == "gemini-yolo" || "$TASK_NAME" == gemini-yolo-* ]]; then
    printf 'exec gemini --yolo\n'
    return 0
  fi

  if [[ -z "$CODEX_CMD" ]]; then
    printf 'exec bash\n'
    return 0
  fi

  local codex_executable="${CODEX_CMD%% *}"

  if [[ "$codex_executable" == /* ]]; then
    printf 'export PATH=%q:"$PATH"\n' "$(dirname "$codex_executable")"
  fi

  cat <<'EOF'
eval "$CODEX_CMD"
status=$?

if [[ $status -ne 0 ]]; then
  printf '\nctask: startup command failed with exit status %s\n' "$status" >&2
  printf 'ctask: CODEX_CMD=%q\n' "$CODEX_CMD" >&2
  printf 'ctask: CODEX_WORKDIR=%q\n' "$CODEX_WORKDIR" >&2
  printf 'ctask: dropping into an interactive shell for debugging.\n' >&2
  exec bash
fi
EOF
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
  echo "CODEX_WORKDIR does not exist or is not a directory: $WORKDIR" >&2
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
