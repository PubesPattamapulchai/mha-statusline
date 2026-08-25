# Installs the My Hero Academia statusline for Claude Code.
# Pure PowerShell — no node, no npm, no jq, no admin rights required.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $HOME '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

$src = Join-Path $PSScriptRoot 'statusline.ps1'
$dest = Join-Path $claudeDir 'statusline.ps1'
Copy-Item -Path $src -Destination $dest -Force

# Aizawa-sensei review subagent + /aizawa-review command (optional bonus,
# same "just copy the file" install as everything else here).
$agentsDir = Join-Path $claudeDir 'agents'
New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'agents\aizawa.md') -Destination (Join-Path $agentsDir 'aizawa.md') -Force

$commandsDir = Join-Path $claudeDir 'commands'
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'commands\aizawa-review.md') -Destination (Join-Path $commandsDir 'aizawa-review.md') -Force

$settingsPath = Join-Path $claudeDir 'settings.json'
if (Test-Path $settingsPath) {
    $settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

$statusLine = [PSCustomObject]@{
    type    = 'command'
    command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$dest`""
}

if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    $settings.statusLine = $statusLine
} else {
    $settings | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $statusLine
}

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

Write-Host "Installed to $dest" -ForegroundColor Green
Write-Host "settings.json updated: $settingsPath" -ForegroundColor Green
Write-Host "Restart Claude Code (or open a new session) to see the new statusline." -ForegroundColor Yellow
Write-Host "Try the strict reviewer: /aizawa-review" -ForegroundColor Yellow
