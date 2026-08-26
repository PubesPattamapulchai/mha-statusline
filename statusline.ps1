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

# The short career-stage code shown for a level — a U.A. student climbing
# through school years, a license, a sidekick job, your own agency, and
# finally the JP Hero Billboard Chart counting down toward #1.
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
        Label     = 'Deku (Midoriya Izuku)'
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
        Label     = 'All Might (Yaki Toshinori)'
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
        Quirk     = Ansi256 160   # Creation — crimson leotard
        Agency    = Ansi 97
        Cooldown  = Ansi256 223   # cream/tan waist belt
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
        Quirk     = Ansi256 54    # Dark Shadow — black robe, dark-purple tint
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
        Quirk     = Ansi256 63    # Dupli-Arms — blue tank top, indigo mask/boots
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
    'shinzo' = @{
        Label     = 'Shinzo (Hitoshi)'
        QuirkIcon = '🧠'
        Quirk     = Ansi256 93    # Brainwash — deep violet
        Agency    = Ansi 97
        Cooldown  = Ansi256 60    # muted indigo — underground, night-hidden
        Hero      = 'NightHide'
    }
}

# Rotation order for auto theme-cycling (see below) — students sorted A-Z by
# character name (Aoyama first, Yaoyorozu/Momo last), with the two teachers
# Aizawa-sensei and All Might held back to the final two slots. Not
# set-theme.ps1's menu order. Plain @{} hashtables in PowerShell don't
# preserve insertion order, so this array is the one place that does.
$ThemeOrder = @(
    'aoyama', 'ashido', 'asui', 'bakugo', 'deku', 'hagakure', 'iida', 'jiro',
    'kaminari', 'kirishima', 'koda', 'mineta', 'ojiro', 'sato', 'sero',
    'shinzo', 'shoji', 'todoroki', 'tokoyami', 'uraraka', 'momo',
    'aizawa', 'allmight'
)

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

# 'auto' (and no saved theme at all) means "don't pin one, cycle the whole
# roster automatically". This is purely a function of wall-clock time, not a
# background process or scheduled task: statusline.ps1 re-runs on every
# render, and Claude Code renders often enough that a 5-minute bucket feels
# live. Deriving the bucket from UTC time (not random) keeps parallel
# sessions/panes in agreement on which theme is "current" right now.
if (-not $themeKey -or $themeKey -eq 'auto') {
    $epochMinutes = [math]::Floor(([DateTimeOffset]::UtcNow).ToUnixTimeSeconds() / 60)
    $bucket = [math]::Floor($epochMinutes / 5)
    $themeKey = $ThemeOrder[$bucket % $ThemeOrder.Count]
} elseif (-not $Themes.ContainsKey($themeKey)) {
    $themeKey = 'deku'
}
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

# Rank (hero level) is driven live by this week's usage — the same
# rate_limits.seven_day.used_percentage Claude Code already reports (see
# Cooldown below). No accumulated state file, no Stop hook: the harder you're
# leaning on Claude this week, the higher your level climbs, and it eases
# back down as that window rolls over. 0-100% maps onto Lv1-40, the full
# range Get-RankAbbrev knows how to label. Missing week data (older CLI or a
# plan without rate limits) just means "no signal yet": Lv1, empty bar.
function Get-LevelFromWeekPct($weekPct) {
    if ($null -eq $weekPct) { return @{ Level = 1; Progress = 0.0 } }
    $exact = [math]::Max(0.0, [math]::Min(100.0, [double]$weekPct)) * 0.39
    $level = [math]::Min(40, 1 + [math]::Floor($exact))
    $progress = $exact - [math]::Floor($exact)
    if ($level -ge 40) { $progress = 1.0 }   # maxed out — show a full bar, not a stalled one
    return @{ Level = [int]$level; Progress = $progress }
}

$rankInfo = Get-LevelFromWeekPct $week
$rankLevel = $rankInfo.Level
$rankAbbrev = Get-RankAbbrev $rankLevel

$barSegments = 5
$rankFilled = [math]::Min($barSegments, [math]::Floor($rankInfo.Progress * $barSegments))
$rankBar = ('▰' * $rankFilled) + ('▱' * ($barSegments - $rankFilled))

$rankPart = "$C_QUIRK$rankAbbrev · Lv$rankLevel $rankBar$RESET"

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

# UA's motto, always shown last — theme-neutral (not tied to any character's
# accent color) since it's the school's line, not any one hero's.
$mottoPart = "$BOLD$(Ansi256 201)Go beyond, Plus Ultra! 💪$RESET"

# One line: Quirk, Agency, Rank, (if present) Cooldown, then the motto.
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add($quirkPart)
$parts.Add($agencyPart)
$parts.Add($rankPart)
if ($cooldownPart) { $parts.Add($cooldownPart) }
$parts.Add($mottoPart)
$line = $parts -join $separator

$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write($line)
$stdoutWriter.Flush()
