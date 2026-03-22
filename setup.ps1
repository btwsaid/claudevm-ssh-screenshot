# claude-screenshot setup
# Interactive setup script for Windows host.

$ErrorActionPreference = "Stop"

Write-Host "=== claude-screenshot setup ===" -ForegroundColor Cyan
Write-Host ""

# Check OpenSSH
if (-not (Get-Command scp.exe -ErrorAction SilentlyContinue)) {
    Write-Error "scp.exe not found. Windows OpenSSH client is required.`nEnable it in Settings > Apps > Optional Features > OpenSSH Client."
    exit 1
}
Write-Host "[OK] scp.exe found" -ForegroundColor Green

# Prompt for VM details
Write-Host ""
$vmHost = Read-Host "VM IP address"
$vmUser = Read-Host "VM SSH username"
$vmPort = Read-Host "VM SSH port (default: 22)"
if (-not $vmPort) { $vmPort = "22" }
$remotePath = Read-Host "Screenshots path on the VM (default: /home/$vmUser/screenshots)"
if (-not $remotePath) { $remotePath = "/home/$vmUser/screenshots" }
if ($remotePath -match '[:\\]') {
    Write-Warning "That looks like a Windows path. This should be a Linux path on the VM (e.g. /home/$vmUser/screenshots)."
    $remotePath = Read-Host "Screenshots path on the VM"
}

# SSH key
$sshKey = ""
$useKey = Read-Host "Use SSH key authentication? (y/N)"
if ($useKey -eq "y") {
    $defaultKey = "$env:USERPROFILE\.ssh\id_rsa"
    $sshKey = Read-Host "SSH key path (default: $defaultKey)"
    if (-not $sshKey) { $sshKey = $defaultKey }
    if (-not (Test-Path $sshKey)) {
        Write-Warning "Key not found at $sshKey"
        $generate = Read-Host "Generate a new key pair? (y/N)"
        if ($generate -eq "y") {
            & ssh-keygen.exe -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
            $sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
            Write-Host "Key generated. Copying public key to VM..." -ForegroundColor Yellow
            Get-Content "$sshKey.pub" | & ssh.exe -p $vmPort "$vmUser@$vmHost" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Public key copied to VM" -ForegroundColor Green
            } else {
                Write-Warning "Failed to copy key. You may need to copy it manually:"
                Write-Host "  type $sshKey.pub | ssh -p $vmPort $vmUser@$vmHost `"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys`""
            }
        }
    }
}

# Test SSH
Write-Host ""
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
$sshArgs = @("-p", $vmPort, "-o", "ConnectTimeout=5")
if ($sshKey -and (Test-Path $sshKey)) {
    $sshArgs += @("-i", $sshKey)
}
$sshArgs += @("$vmUser@$vmHost", "echo ok")

$sshResult = & ssh.exe @sshArgs 2>&1
if ($LASTEXITCODE -ne 0 -or $sshResult -ne "ok") {
    Write-Warning "SSH connection failed: $sshResult"
    Write-Warning "Fix SSH connectivity before continuing."
    $cont = Read-Host "Continue anyway? (y/N)"
    if ($cont -ne "y") { exit 1 }
} else {
    Write-Host "[OK] SSH connection successful" -ForegroundColor Green
}

# Auto-delete option
$autoDelete = Read-Host "Delete local screenshots after upload? (y/N)"
$autoDeleteVal = if ($autoDelete -eq "y") { '$true' } else { '$false' }

# Screenshots folder - detect OneDrive redirection
$picturesFolder = [Environment]::GetFolderPath('MyPictures')
$screenshotsDir = Join-Path $picturesFolder "Screenshots"
if (-not (Test-Path $screenshotsDir)) {
    New-Item -ItemType Directory -Path $screenshotsDir -Force | Out-Null
    Write-Host "Created: $screenshotsDir" -ForegroundColor Green
}

# Write config
$configDir = "$env:USERPROFILE\.config\claude-screenshot"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$configContent = @"
# claude-screenshot configuration
`$VM_HOST = "$vmHost"
`$VM_USER = "$vmUser"
`$VM_PORT = $vmPort
`$REMOTE_PATH = "$remotePath"
`$LOCAL_SCREENSHOTS = "$screenshotsDir"
`$AUTO_DELETE = $autoDeleteVal
`$SSH_KEY = "$sshKey"
"@

$configPath = "$configDir\config.ps1"
Set-Content -Path $configPath -Value $configContent
Write-Host "[OK] Config written to $configPath" -ForegroundColor Green

# Test upload
Write-Host ""
$runTest = Read-Host "Run upload test? (Y/n)"
if ($runTest -ne "n") {
    $testFile = "$screenshotsDir\test_claude_screenshot.png"

    # Create a minimal valid PNG (1x1 white pixel)
    $pngBytes = [byte[]]@(
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21, 0xBC,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,  # IEND chunk
        0x44, 0xAE, 0x42, 0x60, 0x82
    )
    [System.IO.File]::WriteAllBytes($testFile, $pngBytes)

    $scpArgs = @("-P", $vmPort)
    if ($sshKey -and (Test-Path $sshKey)) {
        $scpArgs += @("-i", $sshKey)
    }
    $scpArgs += @($testFile, "$vmUser@${vmHost}:$remotePath/")

    $result = & scp.exe @scpArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Test upload successful" -ForegroundColor Green

        # Clean up
        & ssh.exe -p $vmPort $(if ($sshKey) { @("-i", $sshKey) } else { @() }) "$vmUser@$vmHost" "rm -f $remotePath/test_claude_screenshot.png" 2>&1 | Out-Null
    } else {
        Write-Warning "Test upload failed: $result"
    }
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
}

# Scheduled Task
Write-Host ""
$createTask = Read-Host "Create Scheduled Task to run watcher at logon? (y/N)"
if ($createTask -eq "y") {
    $scriptPath = Join-Path $PSScriptRoot "screenshot_watcher.ps1"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName "claude-screenshot-watcher" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName "claude-screenshot-watcher"
    Write-Host "[OK] Scheduled Task created and started: claude-screenshot-watcher" -ForegroundColor Green
    Write-Host "  The watcher is running now and will start automatically at logon." -ForegroundColor Gray
}

# Snipping Tool guidance
Write-Host ""
Write-Host "=== Screenshot Configuration ===" -ForegroundColor Cyan
Write-Host "To auto-save Win+Shift+S screenshots to ${screenshotsDir}:"
Write-Host "  1. Open Snipping Tool"
Write-Host "  2. Go to Settings (gear icon)"
Write-Host '  3. Toggle "Automatically save screenshots" ON'
Write-Host ""
Write-Host "Alternatively, Win+PrintScreen always saves to that folder."
Write-Host ""
Write-Host "=== Setup complete! ===" -ForegroundColor Green
Write-Host "Start the watcher: .\screenshot_watcher.ps1"
