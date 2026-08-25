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

# And gain-xp.ps1, the Stop hook that grows the Rank segment's hero career.
$gainXpDest = Join-Path $claudeDir 'gain-xp.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'gain-xp.ps1') -Destination $gainXpDest -Force

# And the /mha-theme slash command, so switching themes is just a chat command
# instead of a separate terminal invocation.
$commandsDir = Join-Path $claudeDir 'commands'
New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'commands\mha-theme.md') -Destination (Join-Path $commandsDir 'mha-theme.md') -Force

# And villain-alert.ps1, the Notification hook that reskins "Claude needs
# your attention" notifications as themed alerts.
$villainAlertDest = Join-Path $claudeDir 'villain-alert.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'villain-alert.ps1') -Destination $villainAlertDest -Force

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

# Wire gain-xp.ps1 into the Stop hook (fires once per finished assistant turn) so
# the Rank segment's XP/level actually grows. Merge into any existing hooks —
# never clobber hooks other tools/plugins have already configured.
if ($settings.PSObject.Properties.Name -notcontains 'hooks') {
    $settings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value ([PSCustomObject]@{})
}
if ($settings.hooks.PSObject.Properties.Name -notcontains 'Stop') {
    $settings.hooks | Add-Member -MemberType NoteProperty -Name 'Stop' -Value @()
}

$gainXpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$gainXpDest`""
$alreadyWired = $false
foreach ($entry in @($settings.hooks.Stop)) {
    foreach ($h in @($entry.hooks)) {
        if ($h.command -eq $gainXpCommand) { $alreadyWired = $true }
    }
}
if (-not $alreadyWired) {
    $stopEntry = [PSCustomObject]@{
        hooks = @([PSCustomObject]@{ type = 'command'; command = $gainXpCommand; timeout = 5 })
    }
    $settings.hooks.Stop = @(@($settings.hooks.Stop) + $stopEntry)
}

# Wire villain-alert.ps1 into the Notification hook, matched to only the
# "Claude actually needs you" notification types -- not every notification,
# to avoid alert fatigue. Same merge-safe pattern as the Stop hook above.
if ($settings.hooks.PSObject.Properties.Name -notcontains 'Notification') {
    $settings.hooks | Add-Member -MemberType NoteProperty -Name 'Notification' -Value @()
}
$villainAlertCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$villainAlertDest`""
$villainAlertMatcher = 'permission_prompt|agent_needs_input|idle_prompt'
$villainAlreadyWired = $false
foreach ($entry in @($settings.hooks.Notification)) {
    foreach ($h in @($entry.hooks)) {
        if ($h.command -eq $villainAlertCommand) { $villainAlreadyWired = $true }
    }
}
if (-not $villainAlreadyWired) {
    $notificationEntry = [PSCustomObject]@{
        matcher = $villainAlertMatcher
        hooks   = @([PSCustomObject]@{ type = 'command'; command = $villainAlertCommand; timeout = 5 })
    }
    $settings.hooks.Notification = @(@($settings.hooks.Notification) + $notificationEntry)
}

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

Write-Host "Installed to $dest" -ForegroundColor Green
Write-Host "settings.json updated: $settingsPath" -ForegroundColor Green
Write-Host "Restart Claude Code (or open a new session) to see the new statusline." -ForegroundColor Yellow
Write-Host "Change theme anytime: type /mha-theme in Claude Code, or run powershell -NoProfile -ExecutionPolicy Bypass -File `"$claudeDir\set-theme.ps1`"" -ForegroundColor Yellow
Write-Host "Villain alerts wired: a bell + desktop notification fires when Claude needs your input." -ForegroundColor Yellow
Write-Host "Go beyond, Plus Ultra! 💪" -ForegroundColor Magenta
