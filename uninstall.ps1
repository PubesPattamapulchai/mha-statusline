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
$changed = $false

if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    $settings.PSObject.Properties.Remove('statusLine')
    Write-Host "Removed statusLine from $settingsPath" -ForegroundColor Green
    $changed = $true
} else {
    Write-Host "No statusLine entry found — nothing to do." -ForegroundColor Yellow
}

# Remove only mha-statusline's own Stop hook entry (gain-xp.ps1, a legacy XP
# accumulator from before Rank became weekly-usage-based) — leave any other
# hooks in place, since other tools/plugins may share the Stop event.
if ($settings.PSObject.Properties.Name -contains 'hooks' -and $settings.hooks.PSObject.Properties.Name -contains 'Stop') {
    $gainXpDest = Join-Path $HOME '.claude\gain-xp.ps1'
    $gainXpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$gainXpDest`""
    $kept = @(@($settings.hooks.Stop) | Where-Object {
        -not (@($_.hooks) | Where-Object { $_.command -eq $gainXpCommand })
    })
    if ($kept.Count -lt @($settings.hooks.Stop).Count) {
        $settings.hooks.Stop = $kept
        Write-Host "Removed gain-xp.ps1 from the Stop hook." -ForegroundColor Green
        $changed = $true
    }
}

if ($changed) {
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8
}

Write-Host "Restart Claude Code to see the change." -ForegroundColor Yellow
Write-Host "statusline.ps1, set-theme.ps1, commands\mha-theme.md, and any saved theme (mha-theme.txt) are left on disk — delete them manually from $(Join-Path $HOME '.claude') if you want mha-statusline fully gone." -ForegroundColor Yellow
