# Switches the My Hero Academia statusline theme without reinstalling.
# Writes the chosen theme key to ~/.claude/mha-theme.txt, which statusline.ps1
# reads on every invocation.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File set-theme.ps1            # interactive menu
#   powershell -NoProfile -ExecutionPolicy Bypass -File set-theme.ps1 -Theme bakugo
param(
    [ValidateSet('deku', 'uraraka', 'bakugo', 'todoroki', 'allmight')]
    [string]$Theme
)
$ErrorActionPreference = 'Stop'

$themes = [ordered]@{
    'deku'     = 'Deku (Izuku Midoriya) — One For All green, hero-red accents [default]'
    'uraraka'  = 'Uraraka (Ochako) — zero-gravity pink, sky-blue cooldown'
    'bakugo'   = 'Bakugo (Katsuki) — explosion orange, olive accents'
    'todoroki' = 'Todoroki (Shoto) — half ice-blue, half fire-red'
    'allmight' = 'All Might — hero-suit blue and gold'
}

if (-not $Theme) {
    Write-Host ""
    Write-Host "Choose a My Hero Academia statusline theme:" -ForegroundColor Cyan
    $keys = @($themes.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host ("  [{0}] {1} — {2}" -f ($i + 1), $keys[$i], $themes[$keys[$i]])
    }
    Write-Host ""
    $choice = Read-Host "Enter a number (1-$($keys.Count)), or a theme name [default: deku]"
    if (-not $choice) {
        $Theme = 'deku'
    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $keys.Count) {
        $Theme = $keys[[int]$choice - 1]
    } elseif ($themes.Contains($choice.Trim().ToLowerInvariant())) {
        $Theme = $choice.Trim().ToLowerInvariant()
    } else {
        Write-Host "Didn't recognize '$choice' — defaulting to deku." -ForegroundColor Yellow
        $Theme = 'deku'
    }
}

$claudeDir = Join-Path $HOME '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$themeFile = Join-Path $claudeDir 'mha-theme.txt'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($themeFile, $Theme, $utf8NoBom)

Write-Host "Theme set to '$Theme' ($($themes[$Theme]))." -ForegroundColor Green
Write-Host "Restart Claude Code (or open a new session) to see it." -ForegroundColor Yellow
