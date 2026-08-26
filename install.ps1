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

# Also deploy set-theme.ps1 so switching themes later doesn't require the repo checkout.
Copy-Item -Path (Join-Path $PSScriptRoot 'set-theme.ps1') -Destination (Join-Path $claudeDir 'set-theme.ps1') -Force

# And the /mha-theme slash command, so switching themes is just a chat command
# instead of a separate terminal invocation.
$commandsDir = Join-Path $claudeDir 'commands'
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'commands\mha-theme.md') -Destination (Join-Path $commandsDir 'mha-theme.md') -Force

# Only prompt for a theme on first install — re-running install.ps1 to pick up a
# script update shouldn't reset a theme you already chose via set-theme.ps1.
$themeFile = Join-Path $claudeDir 'mha-theme.txt'
if (-not (Test-Path $themeFile)) {
    & (Join-Path $PSScriptRoot 'set-theme.ps1')
}

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

# Legacy cleanup: older installs wired a gain-xp.ps1 Stop hook to accumulate
# XP for the Rank segment. Rank is now computed live from weekly usage
# (rate_limits.seven_day.used_percentage) instead, so that hook and its state
# file are dead weight — remove them if an earlier install left them behind.
# Never touches hooks other tools/plugins have configured on Stop.
$legacyGainXpDest = Join-Path $claudeDir 'gain-xp.ps1'
$legacyStateFile = Join-Path $claudeDir 'mha-statusline-state.json'
if ($settings.PSObject.Properties.Name -contains 'hooks' -and $settings.hooks.PSObject.Properties.Name -contains 'Stop') {
    $legacyGainXpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$legacyGainXpDest`""
    $kept = @(@($settings.hooks.Stop) | Where-Object {
        -not (@($_.hooks) | Where-Object { $_.command -eq $legacyGainXpCommand })
    })
    if ($kept.Count -lt @($settings.hooks.Stop).Count) {
        $settings.hooks.Stop = $kept
        Write-Host "Removed legacy gain-xp.ps1 Stop hook (Rank is now weekly-usage-based)." -ForegroundColor Yellow
    }
}
Remove-Item -Path $legacyGainXpDest, $legacyStateFile -Force -ErrorAction SilentlyContinue

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

Write-Host "Installed to $dest" -ForegroundColor Green
Write-Host "settings.json updated: $settingsPath" -ForegroundColor Green
Write-Host "Restart Claude Code (or open a new session) to see the new statusline." -ForegroundColor Yellow
Write-Host "Change theme anytime: type /mha-theme in Claude Code, or run powershell -NoProfile -ExecutionPolicy Bypass -File `"$claudeDir\set-theme.ps1`"" -ForegroundColor Yellow
Write-Host "Default theme is 'auto' -- it cycles the whole roster every 5 minutes. Pin one with /mha-theme <name> any time." -ForegroundColor Yellow
Write-Host "Go beyond, Plus Ultra! 💪" -ForegroundColor Magenta
