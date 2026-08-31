# Exports this machine's hero-career stats (theme, hero name, level, XP) as
# a small JSON blob, for the Class 1-A roster viewer (class-roster.html).
#
# v1 of the "multi-machine leaderboard" idea is deliberately manual: run
# this on each machine, collect the printed JSON from each, paste them all
# into class-roster.html. No sync server, no shared backend -- see
# docs/PROJECT-IDEAS.md #7 for why that's the right amount of infrastructure
# for a feature nobody's confirmed they need yet.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File export-stats.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File export-stats.ps1 -Label "work laptop" -OutFile stats.json
param(
    [string]$Label = $env:COMPUTERNAME,
    [string]$OutFile
)
$ErrorActionPreference = 'SilentlyContinue'

function Get-XpToNext([int]$level) { 50 + ($level - 1) * 15 }
function Get-RankAbbrev([int]$level) {
    if ($level -ge 40) {
        $rank = [math]::Max(1, 300 - ($level - 40) * 5)
        return "#$rank"
    }
    if ($level -ge 30) { return 'Agency Founder' }
    if ($level -ge 20) { return 'Sidekick' }
    if ($level -ge 15) { return 'License' }
    if ($level -ge 10) { return 'Y3' }
    if ($level -ge 5)  { return 'Y2' }
    return 'Y1'
}

# Icon + hero-name only, not the full color catalogue -- same call as
# villain-alert.ps1: this output is plain JSON text, nothing here renders
# ANSI color, so there'd be nothing to do with the colors even if included.
$HeroNames = @{
    'deku'      = @{ Icon = '✊'; Name = 'Deku' }
    'uraraka'   = @{ Icon = '🪐'; Name = 'Uravity' }
    'bakugo'    = @{ Icon = '💥'; Name = 'Dynamight' }
    'todoroki'  = @{ Icon = '❄️'; Name = 'Shoto' }
    'allmight'  = @{ Icon = '💪'; Name = 'All Might' }
    'iida'      = @{ Icon = '🦿'; Name = 'Ingenium' }
    'momo'      = @{ Icon = '✨'; Name = 'Creati' }
    'kirishima' = @{ Icon = '🪨'; Name = 'Red Riot' }
    'kaminari'  = @{ Icon = '⚡'; Name = 'Chargezuma' }
    'jiro'      = @{ Icon = '🎧'; Name = 'Earphone Jack' }
    'tokoyami'  = @{ Icon = '🌑'; Name = 'Tsukuyomi' }
    'ashido'    = @{ Icon = '🧪'; Name = 'Pinky' }
    'asui'      = @{ Icon = '🐸'; Name = 'Froppy' }
    'shoji'     = @{ Icon = '🐙'; Name = 'Tentacole' }
    'sato'      = @{ Icon = '🍬'; Name = 'Sugarman' }
    'sero'      = @{ Icon = '📼'; Name = 'Cellophane' }
    'aoyama'    = @{ Icon = '💫'; Name = "Can't Stop Twinkling" }
    'ojiro'     = @{ Icon = '🐒'; Name = 'Tailman' }
    'hagakure'  = @{ Icon = '🫥'; Name = 'Invisible Girl' }
    'koda'      = @{ Icon = '🦉'; Name = 'Anima' }
    'mineta'    = @{ Icon = '🟣'; Name = 'Grape Juice' }
    'aizawa'    = @{ Icon = '🧣'; Name = 'Eraser Head' }
}

$claudeDir = Join-Path $HOME '.claude'

$themeKey = $env:MHA_STATUSLINE_THEME
if (-not $themeKey) {
    $themeFile = Join-Path $claudeDir 'mha-theme.txt'
    if (Test-Path $themeFile) { $themeKey = Get-Content -Raw $themeFile }
}
if ($themeKey) { $themeKey = $themeKey.Trim([char]0xFEFF, ' ', "`r", "`n").ToLowerInvariant() }
if (-not $themeKey -or -not $HeroNames.ContainsKey($themeKey)) { $themeKey = 'deku' }
$hero = $HeroNames[$themeKey]

$stateFile = Join-Path $claudeDir 'mha-statusline-state.json'
$state = $null
if (Test-Path $stateFile) {
    try { $state = Get-Content -Raw $stateFile | ConvertFrom-Json } catch { $state = $null }
}
$level = if ($state -and $state.level) { [int]$state.level } else { 1 }
$xp = if ($state -and $null -ne $state.xp) { [int]$state.xp } else { 0 }
$totalXp = if ($state -and $null -ne $state.totalXp) { [int]$state.totalXp } else { 0 }

$export = [PSCustomObject]@{
    label      = $Label
    theme      = $themeKey
    icon       = $hero.Icon
    heroName   = $hero.Name
    level      = $level
    xp         = $xp
    xpToNext   = Get-XpToNext $level
    totalXp    = $totalXp
    rankStage  = Get-RankAbbrev $level
    exportedAt = (Get-Date).ToUniversalTime().ToString('o')
}

$json = $export | ConvertTo-Json -Depth 5

if ($OutFile) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, $json, $utf8NoBom)
    Write-Host "Wrote $OutFile" -ForegroundColor Green
    Write-Host "Open class-roster.html and load this file (or paste its contents) to add it to the board." -ForegroundColor Yellow
} else {
    # Same reasoning as statusline.ps1's header comment: PowerShell's default
    # console encoding is the legacy codepage, which mangles the emoji in
    # this JSON to "??" under Write-Output/Write-Host. Write UTF-8 bytes
    # straight to the console's OS handle instead.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
    $stdoutWriter.WriteLine($json)
    $stdoutWriter.Flush()
}
