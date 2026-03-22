#!/usr/bin/env bash
# VM-side setup for claude-screenshot
# Run this on your VirtualBox VM to create the screenshots directory.

set -euo pipefail

SCREENSHOTS_DIR="${1:-$HOME/screenshots}"

mkdir -p "$SCREENSHOTS_DIR"

echo "Screenshots directory created: $SCREENSHOTS_DIR"
echo "Use this path as REMOTE_PATH in your Windows config."
