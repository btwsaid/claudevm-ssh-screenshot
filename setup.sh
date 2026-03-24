#!/usr/bin/env bash
# claude-screenshot setup
# Run this on the VM. It sets up the VM side, then copies files to Windows
# and runs setup.ps1 on the Windows host via SSH.

set -euo pipefail

SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$HOME/screenshots}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== claude-screenshot setup ==="
echo ""

# --- VM side ---
echo "[VM] Creating screenshots directory..."
mkdir -p "$SCREENSHOTS_DIR"
echo "[OK] $SCREENSHOTS_DIR"
echo ""

# --- Windows side ---
read -rp "Windows username: " WIN_USER
read -rp "Windows IP address: " WIN_HOST
read -rp "Windows SSH port (default: 22): " WIN_PORT
WIN_PORT="${WIN_PORT:-22}"

REMOTE_DIR="/Users/$WIN_USER/Documents/claude-screenshot"

echo ""
echo "[Windows] Testing SSH connection..."
if ssh -p "$WIN_PORT" -o ConnectTimeout=5 "$WIN_USER@$WIN_HOST" "echo ok" 2>/dev/null | grep -q "ok"; then
    echo "[OK] SSH connection successful"
else
    echo "[WARN] SSH connection failed."
    echo "  Windows needs OpenSSH Server enabled:"
    echo "  Settings > Apps > Optional Features > OpenSSH Server"
    echo "  Then: Start-Service sshd"
    echo ""
    echo "  Without SSH, copy files manually to Windows:"
    echo "    scp -P $WIN_PORT -r $SCRIPT_DIR $WIN_USER@$WIN_HOST:$REMOTE_DIR"
    echo "  Then run setup.ps1 on Windows."
    exit 1
fi

echo ""
echo "[Windows] Copying files..."
ssh -p "$WIN_PORT" "$WIN_USER@$WIN_HOST" "mkdir -p '$REMOTE_DIR'" 2>/dev/null || true
scp -P "$WIN_PORT" \
    "$SCRIPT_DIR/screenshot_watcher.ps1" \
    "$SCRIPT_DIR/setup.ps1" \
    "$SCRIPT_DIR/uninstall.ps1" \
    "$SCRIPT_DIR/config.example.ps1" \
    "$WIN_USER@$WIN_HOST:$REMOTE_DIR/"
echo "[OK] Files copied to $REMOTE_DIR"

echo ""
echo "[Windows] Running setup.ps1..."
ssh -p "$WIN_PORT" "$WIN_USER@$WIN_HOST" "powershell.exe -ExecutionPolicy Bypass -File '$REMOTE_DIR\\setup.ps1'"

echo ""
echo "=== Setup complete! ==="
