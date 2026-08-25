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

# "UA Hero Briefing" output style (optional bonus). Copying the file alone
# does not activate it - Claude Code only applies an output style once you
# select it via /config or set outputStyle in settings.json - so this is
# safe to always drop in; it does nothing until you opt in yourself.
$outputStylesDir = Join-Path $claudeDir 'output-styles'
New-Item -ItemType Directory -Force -Path $outputStylesDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'output-styles\ua-hero.md') -Destination (Join-Path $outputStylesDir 'ua-hero.md') -Force

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
Write-Host "Optional: try the 'UA Hero Briefing' output style via /config (not enabled by default)." -ForegroundColor Yellow
