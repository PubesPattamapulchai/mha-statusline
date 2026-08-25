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
    $levelBefore = [int]$state.level

    while ([int]$state.xp -ge (Get-XpToNext ([int]$state.level))) {
        $state.xp = [int]$state.xp - (Get-XpToNext ([int]$state.level))
        $state.level = [int]$state.level + 1
    }

    # Quirk Registry: crossing a multiple-of-10 level is a level-up banner
    # moment. Record the highest one just crossed (a single big XP grant can
    # jump several at once) plus an expiry timestamp -- statusline.ps1 shows
    # the banner only while "now" is before that expiry, then it lapses on
    # its own. Deliberately NOT "show until acknowledged": Stop-hook stdout
    # isn't shown to the user directly (only to the debug log / Claude's own
    # context, confirmed against the current hooks docs before building
    # this), so there is no reliable "hook prints it once" channel here --
    # a time-boxed flag that statusline.ps1 (which IS always rendered) picks
    # up is the only channel that actually reaches the terminal.
    $levelAfter = [int]$state.level
    $milestone = 0
    for ($lvl = $levelBefore + 1; $lvl -le $levelAfter; $lvl++) {
        if ($lvl % 10 -eq 0) { $milestone = $lvl }
    }
    if ($milestone -gt 0) {
        $bannerLevel = $milestone
        $bannerUntil = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 20
        if ($state.PSObject.Properties.Name -contains 'bannerLevel') {
            $state.bannerLevel = $bannerLevel
        } else {
            $state | Add-Member -MemberType NoteProperty -Name 'bannerLevel' -Value $bannerLevel
        }
        if ($state.PSObject.Properties.Name -contains 'bannerUntil') {
            $state.bannerUntil = $bannerUntil
        } else {
            $state | Add-Member -MemberType NoteProperty -Name 'bannerUntil' -Value $bannerUntil
        }
    }

    $tmpFile = "$stateFile.tmp"
    $state | ConvertTo-Json | Set-Content -Path $tmpFile -Encoding utf8 -NoNewline
    Move-Item -Path $tmpFile -Destination $stateFile -Force
} finally {
    Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
}
