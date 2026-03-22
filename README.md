# claude-screenshot

Automatically upload Windows screenshots to a VirtualBox VM for use with Claude Code.

When running Claude Code on a VM via SSH, you can't paste screenshots directly. This tool watches for new screenshots on your Windows machine, uploads them via SCP, and copies the remote path to your clipboard so you can paste it into Claude Code.

## How It Works

1. Take a screenshot on Windows (Win+Shift+S, Win+PrintScreen, etc.)
2. Screenshot auto-saves to your Pictures\Screenshots folder
3. Watcher detects the new file and uploads it to the VM via SCP
4. Remote file path is copied to your clipboard
5. Paste the path into Claude Code

## Prerequisites

- **Windows 11** with OpenSSH client (built-in)
- SSH access to your VM (bridged networking recommended)
- PowerShell 5.1+ (ships with Windows)

## Quick Start

### 1. Set up the VM (one-time)

SSH into your VM and run:

```bash
bash setup_vm.sh
```

This creates `~/screenshots/`. Nothing else needs to be done on the VM — this persists across reboots.

### 2. Set up Windows (one-time)

Open PowerShell in the repo directory and run:

```powershell
.\setup.ps1
```

The setup script will:
- Verify `scp.exe` is available
- Prompt for VM connection details
- Set up SSH key authentication
- Auto-detect your screenshots folder (handles OneDrive redirection)
- Write config to `~\.config\claude-screenshot\config.ps1`
- Run an upload test
- Optionally create a Scheduled Task to run the watcher at logon

### 3. Take a screenshot

Once the watcher is running, just take a screenshot and paste the path from your clipboard into Claude Code.

## Snipping Tool Configuration

By default, Win+Shift+S copies to clipboard only. To auto-save screenshots:

1. Open **Snipping Tool**
2. Go to **Settings** (gear icon)
3. Toggle **"Automatically save screenshots"** ON

Alternatively, **Win+PrintScreen** always saves to the Screenshots folder.

## Managing the Watcher

### Check if it's running

```powershell
# Check the Scheduled Task status
Get-ScheduledTask -TaskName "claude-screenshot-watcher" | Select-Object State

# Check if the process is running
Get-Process powershell | Where-Object {$_.CommandLine -like "*screenshot_watcher*"}
```

### Start it

```powershell
# Start via Scheduled Task (runs hidden in background)
Start-ScheduledTask -TaskName "claude-screenshot-watcher"

# Or run manually in the foreground (useful for debugging)
.\screenshot_watcher.ps1
```

### Stop it

```powershell
# Stop the Scheduled Task
Stop-ScheduledTask -TaskName "claude-screenshot-watcher"

# Or if running manually, just press Ctrl+C
```

### Restart it

```powershell
Stop-ScheduledTask -TaskName "claude-screenshot-watcher"
Start-ScheduledTask -TaskName "claude-screenshot-watcher"
```

### Remove the Scheduled Task entirely

```powershell
Unregister-ScheduledTask -TaskName "claude-screenshot-watcher" -Confirm:$false
```

### Re-create the Scheduled Task

Run `.\setup.ps1` again, or manually:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Users\User\Documents\claude-screenshot\screenshot_watcher.ps1`""
$trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName "claude-screenshot-watcher" -Action $action -Trigger $trigger -Settings $settings -Force
```

## Daily Usage

1. Boot Windows — watcher starts automatically (hidden, via Scheduled Task)
2. Start VirtualBox VM and wait for it to boot
3. SSH into VM, start Claude Code
4. Take a screenshot (Win+Shift+S or Win+PrintScreen)
5. Paste the path from clipboard into Claude Code

Nothing needs to be done on the VM after initial setup.

## Manual Configuration

Config is stored at `~\.config\claude-screenshot\config.ps1`:

```powershell
$VM_HOST = "192.168.1.85"       # VM IP address
$VM_USER = "tokyo"               # SSH username
$VM_PORT = 22                    # SSH port
$REMOTE_PATH = "/home/tokyo/screenshots"
$LOCAL_SCREENSHOTS = "C:\Users\User\OneDrive\Pictures\Screenshots"
$AUTO_DELETE = $false            # Delete local file after upload
$SSH_KEY = "C:\Users\User\.ssh\id_ed25519"
```

## Troubleshooting

**Screenshots not saving to folder**
- Ensure Snipping Tool auto-save is enabled (see above), or use Win+PrintScreen
- Check your actual screenshots folder: `ls ~/OneDrive/Pictures/Screenshots` or `ls ~/Pictures/Screenshots`

**SSH connection fails**
- Verify VM IP: run `ip addr` on the VM
- Test manually: `ssh -p 22 tokyo@192.168.1.85`
- Check VM firewall: `sudo ufw allow 22` (if using UFW)
- Ensure VM network adapter is set to "Bridged" in VirtualBox

**SCP upload fails**
- Make sure the VM is running and reachable
- Verify the remote directory exists: `ssh tokyo@192.168.1.85 "ls ~/screenshots"`
- Check SSH key: `ssh -i ~/.ssh/id_ed25519 tokyo@192.168.1.85 "echo ok"`

**Watcher not detecting files**
- Check the watcher is watching the right folder (OneDrive may redirect Pictures)
- Run `.\screenshot_watcher.ps1` manually to see output
- Verify screenshots actually appear in the watched folder

**Clipboard error ("Requested Clipboard operation did not succeed")**
- This can happen if the clipboard is locked by Snipping Tool. The watcher retries automatically.
