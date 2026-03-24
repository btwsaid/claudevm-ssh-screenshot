# claude-screenshot uninstall
# Removes the watcher, Scheduled Task, config, and optionally uploaded screenshots.

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== claude-screenshot uninstall ===" -ForegroundColor Cyan
Write-Host ""

# Stop and remove Scheduled Task
$task = Get-ScheduledTask -TaskName "claude-screenshot-watcher" -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName "claude-screenshot-watcher" -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "claude-screenshot-watcher" -Confirm:$false
    Write-Host "[OK] Scheduled Task removed" -ForegroundColor Green
} else {
    Write-Host "[--] No Scheduled Task found" -ForegroundColor Gray
}

# Remove config
$configDir = "$env:USERPROFILE\.config\claude-screenshot"
if (Test-Path $configDir) {
    Remove-Item $configDir -Recurse -Force
    Write-Host "[OK] Config removed: $configDir" -ForegroundColor Green
} else {
    Write-Host "[--] No config found" -ForegroundColor Gray
}

# Remove PowerShell profile functions
$profilePath = $PROFILE
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    $functions = @(
        "function startscreenshot \{[^}]+\}`r?`n?"
        "function stopscreenshot \{[^}]+\}`r?`n?"
        "function screenshotstatus \{[^}]+\}`r?`n?"
    )
    $changed = $false
    foreach ($pattern in $functions) {
        if ($content -match $pattern) {
            $content = $content -replace $pattern, ""
            $changed = $true
        }
    }
    if ($changed) {
        Set-Content -Path $profilePath -Value $content.Trim()
        Write-Host "[OK] Profile functions removed from $profilePath" -ForegroundColor Green
    } else {
        Write-Host "[--] No profile functions found" -ForegroundColor Gray
    }
}

# Optionally remove the script files
Write-Host ""
$removeScripts = Read-Host "Remove script files in $PSScriptRoot? (y/N)"
if ($removeScripts -eq "y") {
    Remove-Item "$PSScriptRoot\screenshot_watcher.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\setup.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\config.example.ps1" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\README.md" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\.gitignore" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\setup_vm.sh" -Force -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot\setup.sh" -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Script files removed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run this to remove the folder:" -ForegroundColor Yellow
    Write-Host "  Remove-Item '$PSScriptRoot' -Recurse -Force"
}

Write-Host ""
Write-Host "=== Windows uninstall complete ===" -ForegroundColor Green
