# Claude Code "Stop" hook for mha-statusline's hero-rank companion feature.
# Fires once per finished assistant turn; awards a small XP gain and handles
# level-ups. Reads/writes ~/.claude/mha-statusline-state.json.
#
# Concurrency: several Claude Code sessions/agents can finish a turn at
# nearly the same instant, so this uses a simple create-new-file spin-lock
# around the read-modify-write, and writes via temp-file + rename so a
# reader (statusline.ps1) never sees a half-written file.
$ErrorActionPreference = 'SilentlyContinue'

$claudeDir = Split-Path -Parent $PSCommandPath   # ~/.claude once installed
$stateFile = Join-Path $claudeDir 'mha-statusline-state.json'
$lockFile  = Join-Path $claudeDir 'mha-statusline-state.lock'

# Must match Get-XpToNext in statusline.ps1 exactly -- it computes the same
# curve to size the displayed XP bar against the level this script already leveled up to.
function Get-XpToNext([int]$level) { 50 + ($level - 1) * 15 }

# Support Course cosmetic unlocks -- crossing one of these levels reskins the
# XP bar's glyph pair (statusline.ps1 applies whichever unlocked tier is
# highest). Must match $UnlockGlyphs' keys in statusline.ps1.
$UnlockLevels = @(5, 10, 15, 20, 30, 40)

$acquired = $false
for ($i = 0; $i -lt 50; $i++) {
    try {
        $fs = [System.IO.File]::Open($lockFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
        $fs.Close()
        $acquired = $true
        break
    } catch {
        Start-Sleep -Milliseconds 50
    }
}
# Give up quietly rather than hold up the hook chain if the lock is stuck.
if (-not $acquired) { exit 0 }

try {
    $state = $null
    if (Test-Path $stateFile) {
        try { $state = Get-Content -Raw $stateFile | ConvertFrom-Json } catch { $state = $null }
    }
    if (-not $state) {
        $state = [PSCustomObject]@{ level = 1; xp = 0; totalXp = 0 }
    }

    $gain = Get-Random -Minimum 8 -Maximum 16
    $state.xp = [int]$state.xp + $gain
    $state.totalXp = [int]$state.totalXp + $gain

    while ([int]$state.xp -ge (Get-XpToNext ([int]$state.level))) {
        $state.xp = [int]$state.xp - (Get-XpToNext ([int]$state.level))
        $state.level = [int]$state.level + 1
    }

    # Record any newly-crossed unlock thresholds. Additive/backward-compatible
    # with state files written before this feature existed (no `unlocks`
    # property yet) -- those just start from an empty list.
    $existingUnlocks = @()
    if ($state.PSObject.Properties.Name -contains 'unlocks' -and $state.unlocks) {
        $existingUnlocks = @($state.unlocks)
    }
    foreach ($lvl in $UnlockLevels) {
        if ([int]$state.level -ge $lvl -and ($existingUnlocks -notcontains $lvl)) {
            $existingUnlocks += $lvl
        }
    }
    if ($state.PSObject.Properties.Name -contains 'unlocks') {
        $state.unlocks = $existingUnlocks
    } else {
        $state | Add-Member -MemberType NoteProperty -Name 'unlocks' -Value $existingUnlocks
    }

    $tmpFile = "$stateFile.tmp"
    $state | ConvertTo-Json | Set-Content -Path $tmpFile -Encoding utf8 -NoNewline
    Move-Item -Path $tmpFile -Destination $stateFile -Force
} finally {
    Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
}
