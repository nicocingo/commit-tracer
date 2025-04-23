#!/bin/bash

# Configuration
COMMAND_NAME="commit-tracer"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="${COMMAND_NAME}.sh"

# Get absolute path to the directory of this script (i.e., the repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}"
TARGET_SCRIPT="${INSTALL_DIR}/${COMMAND_NAME}"

# Check if the source script exists
if [[ ! -f "$SOURCE_SCRIPT" ]]; then
    echo "❌ Error: '${SCRIPT_NAME}' not found in ${SCRIPT_DIR}"
    exit 1
fi

# Ask for sudo permission and install
echo "🔧 Installing '${COMMAND_NAME}' to '${INSTALL_DIR}'..."
sudo cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
sudo chmod +x "$TARGET_SCRIPT"

# Success message
echo "✅ Installation complete!"
echo "You can now use the command: $COMMAND_NAME"
echo "Example:"
echo "  $COMMAND_NAME -h"
