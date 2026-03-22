# claude-screenshot watcher
# Watches for new screenshots and uploads them to a VM via SCP.

$ErrorActionPreference = "Stop"

$configPath = "$env:USERPROFILE\.config\claude-screenshot\config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Error "Config not found at $configPath. Run setup.ps1 first."
    exit 1
}
. $configPath

# Validate required config
foreach ($var in @('VM_HOST', 'VM_USER', 'REMOTE_PATH', 'LOCAL_SCREENSHOTS')) {
    if (-not (Get-Variable -Name $var -ValueOnly -ErrorAction SilentlyContinue)) {
        Write-Error "Missing required config: `$$var"
        exit 1
    }
}

if (-not (Test-Path $LOCAL_SCREENSHOTS)) {
    Write-Error "Screenshots directory not found: $LOCAL_SCREENSHOTS"
    exit 1
}

function Upload-Screenshot {
    param([string]$FilePath)

    $fileName = Split-Path $FilePath -Leaf
    $remoteDest = "${VM_USER}@${VM_HOST}:${REMOTE_PATH}/"
    $remoteFilePath = "${REMOTE_PATH}/$fileName"

    # Wait for file to finish writing and clipboard to be released
    Start-Sleep -Seconds 2

    # Build SCP args
    $scpArgs = @("-P", $VM_PORT)
    if ($SSH_KEY -and (Test-Path $SSH_KEY)) {
        $scpArgs += @("-i", $SSH_KEY)
    }
    $scpArgs += @($FilePath, $remoteDest)

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Uploading $fileName..."

    try {
        $result = & scp.exe @scpArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "SCP failed: $result"
            return
        }

        for ($i = 0; $i -lt 3; $i++) {
            try { Set-Clipboard -Value $remoteFilePath; break } catch { Start-Sleep -Milliseconds 500 }
        }
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Uploaded. Path copied to clipboard: $remoteFilePath"

        if ($AUTO_DELETE) {
            Remove-Item $FilePath -Force
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Deleted local file."
        }
    }
    catch {
        Write-Warning "Upload failed: $_"
    }
}

# Poll for new screenshots
Write-Host "Watching for screenshots in: $LOCAL_SCREENSHOTS"
Write-Host "Uploading to: ${VM_USER}@${VM_HOST}:${REMOTE_PATH}/"
Write-Host "Press Ctrl+C to stop."

$lastCheck = Get-Date

while ($true) {
    Start-Sleep -Seconds 2
    $newFiles = Get-ChildItem $LOCAL_SCREENSHOTS -Filter "*.png" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $lastCheck }
    $lastCheck = Get-Date
    foreach ($file in $newFiles) {
        Upload-Screenshot -FilePath $file.FullName
    }
}
