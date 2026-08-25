# Removes the My Hero Academia statusline config from Claude Code.
# Leaves statusline.ps1 on disk untouched — only clears settings.json's statusLine entry.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $HOME '.claude\settings.json'
if (-not (Test-Path $settingsPath)) {
    Write-Host "No settings.json found at $settingsPath — nothing to do." -ForegroundColor Yellow
    return
}

$settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    $settings.PSObject.Properties.Remove('statusLine')
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8
    Write-Host "Removed statusLine from $settingsPath" -ForegroundColor Green
} else {
    Write-Host "No statusLine entry found — nothing to do." -ForegroundColor Yellow
}

Write-Host "Restart Claude Code to see the change." -ForegroundColor Yellow
