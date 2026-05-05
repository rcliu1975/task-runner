#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_NAME="${2:-ctask}"

echo "Installing ctask to $INSTALL_DIR..."

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "Error: Directory $INSTALL_DIR does not exist."
  exit 1
fi

install -m 0755 scripts/ctask.sh "$INSTALL_DIR/$SCRIPT_NAME"

echo "Successfully installed to $INSTALL_DIR/$SCRIPT_NAME"
echo "You can now run '$SCRIPT_NAME <task-name>' from anywhere."
