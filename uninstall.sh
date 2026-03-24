#!/usr/bin/env bash
# claude-screenshot uninstall
# Run this on the VM. It cleans up the VM side, then optionally
# runs uninstall.ps1 on the Windows host via SSH.

set -euo pipefail

SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$HOME/screenshots}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== claude-screenshot uninstall ==="
echo ""

# --- VM side ---
if [ -d "$SCREENSHOTS_DIR" ]; then
    read -rp "Delete screenshots directory $SCREENSHOTS_DIR and all its contents? (y/N): " del_screenshots
    if [ "$del_screenshots" = "y" ]; then
        rm -rf "$SCREENSHOTS_DIR"
        echo "[OK] $SCREENSHOTS_DIR removed"
    else
        echo "[--] Kept $SCREENSHOTS_DIR"
    fi
else
    echo "[--] No screenshots directory found"
fi

# --- Windows side ---
echo ""
read -rp "Also uninstall from Windows host? (y/N): " do_windows
if [ "$do_windows" = "y" ]; then
    read -rp "Windows username: " WIN_USER
    read -rp "Windows IP address: " WIN_HOST
    read -rp "Windows SSH port (default: 22): " WIN_PORT
    WIN_PORT="${WIN_PORT:-22}"

    REMOTE_DIR="/Users/$WIN_USER/Documents/claude-screenshot"

    echo ""
    echo "[Windows] Copying uninstall script..."
    scp -P "$WIN_PORT" "$SCRIPT_DIR/uninstall.ps1" "$WIN_USER@$WIN_HOST:$REMOTE_DIR/" 2>/dev/null

    echo "[Windows] Running uninstall.ps1..."
    ssh -p "$WIN_PORT" "$WIN_USER@$WIN_HOST" "powershell.exe -ExecutionPolicy Bypass -File '$REMOTE_DIR\\uninstall.ps1'"
fi

echo ""
echo "=== Uninstall complete ==="
