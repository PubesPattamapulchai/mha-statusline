# Claude Code statusline — My Hero Academia theme (pure PowerShell, no node/jq/installs required)
# One line, kept minimal: Quirk (model) | Agency (dir) | Rank (hero level,
# career-stage) | Cooldown (5h/7d rate limits)
$ErrorActionPreference = 'SilentlyContinue'

# PowerShell's default console encoding is the legacy system codepage, which can't
# represent the emoji used below — without this, each one renders as "?"/"??".
# Claude Code always invokes this script with stdin/stdout redirected through pipes,
# and [Console]::OutputEncoding/InputEncoding can only be *set* when a real console
# is attached — assigning them on redirected streams throws, which
# $ErrorActionPreference = 'SilentlyContinue' swallows, silently leaving the legacy
# codepage in place. So instead of touching those properties, read/write UTF-8 bytes
# directly against the underlying OS handles, which works whether redirected or not.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8NoBom)
$raw = $stdinReader.ReadToEnd()
try { $data = $raw | ConvertFrom-Json } catch { $data = $null }

function Get-Prop {
    param($Object, [string[]]$Path)
    $current = $Object
    foreach ($segment in $Path) {
        if ($null -eq $current) { return $null }
        $current = $current.$segment
    }
    return $current
}

$ESC = [char]27
function Ansi([int]$code) { "$ESC[${code}m" }
function Ansi256([int]$code) { "$ESC[38;5;${code}m" }   # closer per-character colors than the base 16

# XP needed to clear a level, and the short career-stage code shown for it — a
# U.A. student climbing through school years, a license, a sidekick job, your
# own agency, and finally the JP Hero Billboard Chart counting down toward #1.
# Mirrors gain-xp.ps1 (the Stop hook that actually grants XP) — kept in sync
# by hand since both are single flat scripts with no shared module.
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

$RESET = Ansi 0
$BOLD  = Ansi 1
$DIM   = Ansi256 244   # neutral gray for separators — content carries the theme color, not punctuation

# ---- Theme catalogue -------------------------------------------------------
# Each theme is a Quirk icon, the handful of colors minimal mode still uses
# (Quirk/rank accent, Agency dir text, Cooldown rate-limit text), and the
# character's hero name. Only the character-specific bits change.
$Themes = @{
    'deku' = @{
        Label     = 'Deku (Izuku Midoriya)'
        QuirkIcon = '✊'
        Quirk     = Ansi256 46    # One For All green
        Agency    = Ansi 97
        Cooldown  = Ansi 96
        Hero      = 'Deku'
    }
    'uraraka' = @{
        Label     = 'Uraraka (Ochako)'
        QuirkIcon = '🪐'
        Quirk     = Ansi256 211   # zero-gravity pink
        Agency    = Ansi 97
        Cooldown  = Ansi256 117   # sky blue — floating
        Hero      = 'Uravity'
    }
    'bakugo' = @{
        Label     = 'Bakugo (Katsuki)'
        QuirkIcon = '💥'
        Quirk     = Ansi256 208   # explosion orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 214
        Hero      = 'Dynamight'
    }
    'todoroki' = @{
        Label     = 'Todoroki (Shoto)'
        QuirkIcon = '❄️'
        Quirk     = Ansi256 45    # ice blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 39
        Hero      = 'Shoto'
    }
    'allmight' = @{
        Label     = 'All Might'
        QuirkIcon = '💪'
        Quirk     = Ansi256 33    # hero-suit blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 33
        Hero      = 'All Might'
    }
    # ---- Rest of Class 1-A ---------------------------------------------
    'iida' = @{
        Label     = 'Iida (Tenya)'
        QuirkIcon = '🦿'
        Quirk     = Ansi256 27    # Engine — exhaust-pipe leg armor blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 33
        Hero      = 'Ingenium'
    }
    'momo' = @{
        Label     = 'Yaoyorozu (Momo)'
        QuirkIcon = '✨'
        Quirk     = Ansi256 160   # Creation — black-and-red hero costume
        Agency    = Ansi 97
        Cooldown  = Ansi256 217
        Hero      = 'Creati'
    }
    'kirishima' = @{
        Label     = 'Kirishima (Eijiro)'
        QuirkIcon = '🪨'
        Quirk     = Ansi256 202   # Hardening — spiky red hair
        Agency    = Ansi 97
        Cooldown  = Ansi256 208
        Hero      = 'Red Riot'
    }
    'kaminari' = @{
        Label     = 'Kaminari (Denki)'
        QuirkIcon = '⚡'
        Quirk     = Ansi256 226   # Electrification — yellow
        Agency    = Ansi 97
        Cooldown  = Ansi256 220
        Hero      = 'Chargezuma'
    }
    'jiro' = @{
        Label     = 'Jiro (Kyoka)'
        QuirkIcon = '🎧'
        Quirk     = Ansi256 141   # Earphone Jack — purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 99
        Hero      = 'Earphone Jack'
    }
    'tokoyami' = @{
        Label     = 'Tokoyami (Fumikage)'
        QuirkIcon = '🌑'
        Quirk     = Ansi256 88    # Dark Shadow — dark red/black
        Agency    = Ansi 97
        Cooldown  = Ansi256 92
        Hero      = 'Tsukuyomi'
    }
    'ashido' = @{
        Label     = 'Ashido (Mina)'
        QuirkIcon = '🧪'
        Quirk     = Ansi256 213   # Acid — pink skin
        Agency    = Ansi 97
        Cooldown  = Ansi256 205
        Hero      = 'Pinky'
    }
    'asui' = @{
        Label     = 'Asui (Tsuyu)'
        QuirkIcon = '🐸'
        Quirk     = Ansi256 34    # Frog — green
        Agency    = Ansi 97
        Cooldown  = Ansi256 82
        Hero      = 'Froppy'
    }
    'shoji' = @{
        Label     = 'Shoji (Mezo)'
        QuirkIcon = '🐙'
        Quirk     = Ansi256 103   # Dupli-Arms — muted purple-gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 60
        Hero      = 'Tentacole'
    }
    'sato' = @{
        Label     = 'Sato (Rikido)'
        QuirkIcon = '🍬'
        Quirk     = Ansi256 172   # Sugar Rush — brown-orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 214
        Hero      = 'Sugarman'
    }
    'sero' = @{
        Label     = 'Sero (Hanta)'
        QuirkIcon = '📼'
        Quirk     = Ansi256 178   # Tape — gold hero suit
        Agency    = Ansi 97
        Cooldown  = Ansi256 178
        Hero      = 'Cellophane'
    }
    'aoyama' = @{
        Label     = 'Aoyama (Yuga)'
        QuirkIcon = '💫'
        Quirk     = Ansi256 220   # Navel Laser — blonde/gold sparkle
        Agency    = Ansi 97
        Cooldown  = Ansi256 226
        Hero      = "Can't Stop Twinkling"
    }
    'ojiro' = @{
        Label     = 'Ojiro (Mashirao)'
        QuirkIcon = '🐒'
        Quirk     = Ansi256 94    # Tail — plain brown gi
        Agency    = Ansi 97
        Cooldown  = Ansi256 137
        Hero      = 'Tailman'
    }
    'hagakure' = @{
        Label     = 'Hagakure (Toru)'
        QuirkIcon = '🫥'
        Quirk     = Ansi256 195   # Invisibility — barely-there white
        Agency    = Ansi 97
        Cooldown  = Ansi256 159
        Hero      = 'Invisible Girl'
    }
    'koda' = @{
        Label     = 'Koda (Koji)'
        QuirkIcon = '🦉'
        Quirk     = Ansi256 22    # Anivoice — quiet forest green
        Agency    = Ansi 97
        Cooldown  = Ansi256 65
        Hero      = 'Anima'
    }
    'mineta' = @{
        Label     = 'Mineta (Minoru)'
        QuirkIcon = '🟣'
        Quirk     = Ansi256 129   # Pop Off — purple sticky balls
        Agency    = Ansi 97
        Cooldown  = Ansi256 93
        Hero      = 'Grape Juice'
    }
    # ---- Homeroom teacher -----------------------------------------------
    'aizawa' = @{
        Label     = 'Aizawa-sensei (Shota)'
        QuirkIcon = '🧣'
        Quirk     = Ansi256 243   # Erasure — tired all-black everything
        Agency    = Ansi 97
        Cooldown  = Ansi256 60
        Hero      = 'Eraser Head'
    }
}

# Pick a theme: $env:MHA_STATUSLINE_THEME overrides the saved config, which
# overrides the default. `mha-theme.txt` lives next to this script — once
# installed that's ~/.claude/mha-theme.txt — so set-theme.ps1 can flip it
# without touching settings.json or reinstalling.
$themeKey = $env:MHA_STATUSLINE_THEME
if (-not $themeKey) {
    $themeFile = Join-Path $PSScriptRoot 'mha-theme.txt'
    if (Test-Path $themeFile) { $themeKey = Get-Content -Raw $themeFile }
}
if ($themeKey) { $themeKey = $themeKey.Trim([char]0xFEFF, ' ', "`r", "`n").ToLowerInvariant() }
if (-not $themeKey -or -not $Themes.ContainsKey($themeKey)) { $themeKey = 'deku' }
$theme = $Themes[$themeKey]

$C_QUIRK    = $theme.Quirk
$C_AGENCY   = $theme.Agency
$C_COOLDOWN = $theme.Cooldown
$QUIRK_ICON = $theme.QuirkIcon
$HERO_NAME  = $theme.Hero

$model = Get-Prop $data @('model', 'display_name')
if (-not $model) { $model = '?' }

$dir = Get-Prop $data @('workspace', 'current_dir')
if (-not $dir) { $dir = Get-Prop $data @('cwd') }
if (-not $dir) { $dir = (Get-Location).Path }
$dirName = Split-Path -Leaf $dir
if (-not $dirName) { $dirName = $dir }

$five = Get-Prop $data @('rate_limits', 'five_hour', 'used_percentage')
$week = Get-Prop $data @('rate_limits', 'seven_day', 'used_percentage')

# Quirk (model), tagged with the character's hero name
$quirkPart = "$BOLD$C_QUIRK$QUIRK_ICON $model$RESET"
if ($HERO_NAME) { $quirkPart += " $BOLD$C_QUIRK$HERO_NAME$RESET" }

# Agency (current dir)
$agencyPart = "$C_AGENCY$dirName$RESET"

# Rank (hero level from gain-xp.ps1's Stop hook — grows one tick per finished
# turn). Missing/unreadable state file just means "not trained yet": Lv1, empty bar.
$rankStateFile = Join-Path $PSScriptRoot 'mha-statusline-state.json'
$rankState = $null
if (Test-Path $rankStateFile) {
    try { $rankState = Get-Content -Raw $rankStateFile | ConvertFrom-Json } catch { $rankState = $null }
}
$rankLevel = if ($rankState -and $rankState.level) { [int]$rankState.level } else { 1 }
$rankXp    = if ($rankState -and $null -ne $rankState.xp) { [int]$rankState.xp } else { 0 }
$rankXpToNext = Get-XpToNext $rankLevel
$rankAbbrev = Get-RankAbbrev $rankLevel

$barSegments = 5
$rankFilled = [math]::Min($barSegments, [math]::Floor(($rankXp / [double]$rankXpToNext) * $barSegments))
$rankBar = ('▰' * $rankFilled) + ('▱' * ($barSegments - $rankFilled))

$rankPart = "$C_QUIRK$rankAbbrev · Lv$rankLevel $rankBar $rankXp/$rankXpToNext$RESET"

# Cooldown (5h/7d rate limits) — the only remaining optional segment
$cooldownPart = $null
if ($null -ne $five -or $null -ne $week) {
    $cooldownStr = "$C_COOLDOWN⏱ "
    if ($null -ne $five) { $cooldownStr += "5h:$([math]::Round([double]$five))%" }
    if ($null -ne $week) {
        if ($null -ne $five) { $cooldownStr += ' ' }
        $cooldownStr += "7d:$([math]::Round([double]$week))%"
    }
    $cooldownStr += $RESET
    $cooldownPart = $cooldownStr
}

$separator = "$DIM · $RESET"

# One line: Quirk, Agency, Rank, and (if present) Cooldown, dot-separated.
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add($quirkPart)
$parts.Add($agencyPart)
$parts.Add($rankPart)
if ($cooldownPart) { $parts.Add($cooldownPart) }
$line = $parts -join $separator

$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write($line)
$stdoutWriter.Flush()
