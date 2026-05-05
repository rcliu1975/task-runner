#!/usr/bin/env bash

set -euo pipefail

# Installation script for task-runner
# Installs codex-task.sh to /usr/local/bin or a user-defined directory

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_NAME="codex-task"

echo "Installing task-runner to $INSTALL_DIR..."

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Error: Directory $INSTALL_DIR does not exist."
  exit 1
fi

cp scripts/codex-task.sh "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "Successfully installed to $INSTALL_DIR/$SCRIPT_NAME"
echo "You can now run 'codex-task <task-name>' from anywhere."
