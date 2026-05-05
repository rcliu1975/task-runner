#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="${2:-ctask}"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
INSTALL_DIR="${1:-$TARGET_HOME/.local/bin}"
CTASK_CONFIG_DIR="${CTASK_CONFIG_DIR:-$TARGET_HOME/.config/ctask}"
CTASK_ENV_FILE="${CTASK_ENV_FILE:-$CTASK_CONFIG_DIR/env.sh}"
LEGACY_ENV_FILE="${LEGACY_ENV_FILE:-$TARGET_HOME/.config/codex-interactive-mode/env.sh}"
DEFAULT_WORKDIR="${DEFAULT_WORKDIR:-$TARGET_HOME/WorkSpace}"
DEFAULT_SOCKET_DIR="${DEFAULT_SOCKET_DIR:-/tmp/ctask-tmux}"
DEFAULT_SESSION_PREFIX="${DEFAULT_SESSION_PREFIX:-ctask}"

if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  echo "Error: Could not determine home directory for user: $TARGET_USER" >&2
  exit 1
fi

as_target_user() {
  if [[ "$(id -un)" == "$TARGET_USER" ]]; then
    "$@"
  else
    sudo -u "$TARGET_USER" "$@"
  fi
}

load_legacy_value() {
  local name="$1"

  if [[ -f "$LEGACY_ENV_FILE" ]]; then
    (
      set +u
      # shellcheck source=/dev/null
      source "$LEGACY_ENV_FILE"
      printf '%s' "${!name:-}"
    )
  fi
}

write_env_file() {
  local workdir="$1"
  local socket_dir="$2"
  local session_prefix="$3"
  local quoted_workdir
  local quoted_socket_dir
  local quoted_session_prefix

  printf -v quoted_workdir '%q' "$workdir"
  printf -v quoted_socket_dir '%q' "$socket_dir"
  printf -v quoted_session_prefix '%q' "$session_prefix"

  as_target_user mkdir -p "$CTASK_CONFIG_DIR"

  if [[ -f "$CTASK_ENV_FILE" && "${CTASK_OVERWRITE_CONFIG:-0}" != "1" ]]; then
    echo "Keeping existing config: $CTASK_ENV_FILE"
    return 0
  fi

  as_target_user tee "$CTASK_ENV_FILE" >/dev/null <<EOF
export CTASK_WORKDIR=$quoted_workdir
export CTASK_SOCKET_DIR=$quoted_socket_dir
export CTASK_SESSION_PREFIX=$quoted_session_prefix
EOF
}

echo "Installing ctask to $INSTALL_DIR..."

as_target_user mkdir -p "$INSTALL_DIR"

if [[ "$(id -un)" == "$TARGET_USER" ]]; then
  install -m 0755 scripts/ctask.sh "$INSTALL_DIR/$SCRIPT_NAME"
else
  install -m 0755 -o "$TARGET_USER" -g "$TARGET_USER" scripts/ctask.sh "$INSTALL_DIR/$SCRIPT_NAME"
fi

legacy_workdir="$(load_legacy_value CODEX_WORKDIR)"
legacy_socket_dir="$(load_legacy_value CODEX_SOCKET_DIR)"
legacy_session_prefix="$(load_legacy_value CODEX_SESSION_PREFIX)"

write_env_file \
  "${legacy_workdir:-$DEFAULT_WORKDIR}" \
  "${legacy_socket_dir:-$DEFAULT_SOCKET_DIR}" \
  "${legacy_session_prefix:-$DEFAULT_SESSION_PREFIX}"

echo "Successfully installed to $INSTALL_DIR/$SCRIPT_NAME"
echo "Config file: $CTASK_ENV_FILE"
echo "You can now run '$SCRIPT_NAME <task-name>' from anywhere."
echo "Make sure $INSTALL_DIR is on PATH."
