#!/usr/bin/env bash

###############################################################################
# ctask = AI Agent Session Manager
#
# 主要功能:
#   - 每個 task 對應一個獨立 tmux session
#   - 自動建立 / 重連 session
#   - 支援 codex、gemini 內建 route
#   - 使用獨立 tmux socket 避免互相干擾
#
# 範例:
#   ctask codex
#   ctask gemini
#   ctask --list
###############################################################################

set -euo pipefail

PROGRAM_NAME="$(basename "$0")"

CONFIG_FILE="${CTASK_CONFIG:-$HOME/.config/ctask/env.sh}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

TASK_NAME="${1:-}"
WORKDIR="${CTASK_WORKDIR:-$HOME/WorkSpace}"
SOCKET_DIR="${CTASK_SOCKET_DIR:-/tmp/ctask-tmux}"
SESSION_PREFIX="${CTASK_SESSION_PREFIX:-ctask}"

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

# 確保 tmux 啟動時也能找到常見工具
# 例如 ~/.local/bin、nvm 安裝的 node/codex/gemini
emit_runtime_path_setup() {
  cat <<'EOF'
if [[ -d "$HOME/.local/bin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ -n "${NVM_BIN:-}" && -d "$NVM_BIN" ]]; then
  export PATH="$NVM_BIN:$PATH"
fi

if [[ -d "$HOME/.nvm/versions/node" ]]; then
  for node_bin in "$HOME"/.nvm/versions/node/*/bin; do
    if [[ -x "$node_bin/node" ]]; then
      export PATH="$node_bin:$PATH"
    fi
  done
fi
EOF
}

build_debug_fallback() {
  cat <<'EOF'
status=$?

if [[ $status -ne 0 ]]; then
  printf '\nctask: startup command failed with exit status %s\n' "$status" >&2
  printf 'ctask: CTASK_WORKDIR=%q\n' "${CTASK_WORKDIR:-}" >&2
  printf 'ctask: dropping into an interactive shell for debugging.\n' >&2
  exec bash
fi
EOF
}

# 內建 route
# ctask codex       -> codex --full-auto
# ctask danger      -> codex danger 模式
# ctask gemini      -> gemini
# ctask gemini-yolo -> gemini --yolo
route_builtin_command() {
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

# 建立 tmux session 啟動指令
# 流程:
#   1. 檢查內建 route
#   2. 找不到則直接進 bash
# 若 AI agent 啟動失敗，會自動掉進 shell 方便除錯
build_start_cmd() {
  local routed_cmd=""
  local task_executable=""

  if routed_cmd="$(route_builtin_command)"; then
    task_executable="${routed_cmd%% *}"
    emit_runtime_path_setup
    quote_path_dir_for_path "$task_executable"
    printf 'eval %q\n' "$routed_cmd"
    build_debug_fallback
    return 0
  fi

  emit_runtime_path_setup
  printf 'exec bash\n'
}

# 檢查指定 tmux session 是否存在
session_exists() {
  local socket_path="$1"
  local session_name="$2"

  tmux -S "$socket_path" has-session -t "$session_name" 2>/dev/null
}

# 列出所有 task socket
# active = session 存在
# stale  = socket 存在但 tmux session 已消失
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

# 建立 socket 目錄
mkdir -p "$SOCKET_DIR"
chmod 700 "$SOCKET_DIR"

SOCKET_PATH="$SOCKET_DIR/${TASK_NAME}.sock"
SESSION_NAME="${SESSION_PREFIX}-${TASK_NAME}"

# 清理殘留 socket
# 例如 tmux 被強制 kill 後留下的 orphan socket
if [[ -S "$SOCKET_PATH" ]] && ! session_exists "$SOCKET_PATH" "$SESSION_NAME"; then
  rm -f "$SOCKET_PATH"
fi

# 如果 session 不存在:
#   建立新的 tmux session
#   執行對應 AI agent 啟動命令
if ! session_exists "$SOCKET_PATH" "$SESSION_NAME"; then
  START_CMD="$(build_start_cmd)"

  tmux -S "$SOCKET_PATH" new-session -d -s "$SESSION_NAME" -c "$WORKDIR" bash -lc "$START_CMD"
fi

# 不論是新建或已存在
# 最後都 attach 回同一個 session
exec tmux -S "$SOCKET_PATH" attach -t "$SESSION_NAME"
