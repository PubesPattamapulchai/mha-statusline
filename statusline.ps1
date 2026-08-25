# Claude Code statusline — My Hero Academia theme (pure PowerShell, no node/jq/installs required)
# Three lines, so nothing gets width-truncated:
#   1. Quirk (model) + Agency (dir + git branch)
#   2. Rank (hero XP/level, grown by gain-xp.ps1's Stop hook)
#   3. Stamina (ctx remaining %) | Cooldown (5h/7d rate limits) | Cost | Combat log (+/- lines)
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

# XP needed to clear a level, and the career-stage title shown for it — a U.A.
# student climbing through school years, a license, a sidekick job, your own
# agency, and finally the JP Hero Billboard Chart counting down toward #1.
# Mirrors gain-xp.ps1 (the Stop hook that actually grants XP) — kept in sync
# by hand since both are single flat scripts with no shared module.
function Get-XpToNext([int]$level) { 50 + ($level - 1) * 15 }
function Get-RankTitle([int]$level) {
    if ($level -ge 40) {
        $rank = [math]::Max(1, 300 - ($level - 40) * 5)
        if ($rank -eq 1) { return 'JP Hero Billboard #1 — Symbol of Peace' }
        return "JP Hero Billboard #$rank"
    }
    if ($level -ge 30) { return 'Agency Founder' }
    if ($level -ge 20) { return 'Hero Assistant (Sidekick)' }
    if ($level -ge 15) { return 'Provisional License Holder' }
    if ($level -ge 10) { return 'U.A. Year 3 Student' }
    if ($level -ge 5)  { return 'U.A. Year 2 Student' }
    return 'U.A. Year 1 Student'
}

$RESET = Ansi 0
$BOLD  = Ansi 1

# ---- Theme catalogue -------------------------------------------------------
# Each theme is a Quirk icon, a color set, and the line shown at Stamina >= 80%.
# 🏫 Agency, ⚡ branch bolt, 🔋 Stamina, ⏱ Cooldown, 🪙 Cost stay literal/universal
# across themes — only the character-specific bits change.
$Themes = @{
    'deku' = @{
        Label     = 'Deku (Izuku Midoriya)'
        QuirkIcon = '✊'
        Quirk     = Ansi256 46    # One For All green
        Agency    = Ansi 97
        Branch    = Ansi256 196   # red boots
        StaOk     = Ansi256 46
        StaWarn   = Ansi256 220
        StaBad    = Ansi256 196
        Cooldown  = Ansi 96
        Cost      = Ansi256 220
        Add       = Ansi256 46
        Del       = Ansi256 196
        Bolt      = Ansi256 220
        Ultra     = 'PLUS ULTRA!'
    }
    'uraraka' = @{
        Label     = 'Uraraka (Ochako)'
        QuirkIcon = '🪐'
        Quirk     = Ansi256 211   # zero-gravity pink
        Agency    = Ansi 97
        Branch    = Ansi256 95    # brown hair
        StaOk     = Ansi256 211
        StaWarn   = Ansi256 220
        StaBad    = Ansi256 196
        Cooldown  = Ansi256 117   # sky blue — floating
        Cost      = Ansi256 220
        Add       = Ansi256 46
        Del       = Ansi256 196
        Bolt      = Ansi256 211
        Ultra     = 'ZERO GRAVITY!'
    }
    'bakugo' = @{
        Label     = 'Bakugo (Katsuki)'
        QuirkIcon = '💥'
        Quirk     = Ansi256 208   # explosion orange
        Agency    = Ansi 97
        Branch    = Ansi256 58    # dark olive tank top
        StaOk     = Ansi256 46
        StaWarn   = Ansi256 220
        StaBad    = Ansi256 196
        Cooldown  = Ansi256 214
        Cost      = Ansi256 220
        Add       = Ansi256 46
        Del       = Ansi256 196
        Bolt      = Ansi256 208
        Ultra     = 'I AM NUMBER ONE!'
    }
    'todoroki' = @{
        Label     = 'Todoroki (Shoto)'
        QuirkIcon = '❄️'
        Quirk     = Ansi256 45    # ice blue
        Agency    = Ansi 97
        Branch    = Ansi256 196   # fire red
        StaOk     = Ansi256 45
        StaWarn   = Ansi256 220
        StaBad    = Ansi256 196
        Cooldown  = Ansi256 39
        Cost      = Ansi256 220
        Add       = Ansi256 46
        Del       = Ansi256 196
        Bolt      = Ansi 97       # steam — where hot meets cold
        Ultra     = 'FLASHFIRE FIST!'
    }
    'allmight' = @{
        Label     = 'All Might'
        QuirkIcon = '💪'
        Quirk     = Ansi256 33    # hero-suit blue
        Agency    = Ansi 97
        Branch    = Ansi256 196
        StaOk     = Ansi256 220
        StaWarn   = Ansi256 214
        StaBad    = Ansi256 196
        Cooldown  = Ansi256 33
        Cost      = Ansi256 220
        Add       = Ansi256 46
        Del       = Ansi256 196
        Bolt      = Ansi256 220
        Ultra     = 'I AM HERE!'
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
$C_BRANCH   = $theme.Branch
$C_STA_OK   = $theme.StaOk
$C_STA_WARN = $theme.StaWarn
$C_STA_BAD  = $theme.StaBad
$C_COOLDOWN = $theme.Cooldown
$C_COST     = $theme.Cost
$C_ADD      = $theme.Add
$C_DEL      = $theme.Del
$C_BOLT     = $theme.Bolt
$QUIRK_ICON = $theme.QuirkIcon
$ULTRA      = $theme.Ultra

$model = Get-Prop $data @('model', 'display_name')
if (-not $model) { $model = '?' }

$dir = Get-Prop $data @('workspace', 'current_dir')
if (-not $dir) { $dir = Get-Prop $data @('cwd') }
if (-not $dir) { $dir = (Get-Location).Path }
$dirName = Split-Path -Leaf $dir
if (-not $dirName) { $dirName = $dir }

$branch = $null
$isRepo = git -C $dir --no-optional-locks rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0) {
    $branch = (git -C $dir --no-optional-locks branch --show-current 2>$null)
    if ($branch) { $branch = $branch.Trim() }
}

$remaining    = Get-Prop $data @('context_window', 'remaining_percentage')
$five         = Get-Prop $data @('rate_limits', 'five_hour', 'used_percentage')
$week         = Get-Prop $data @('rate_limits', 'seven_day', 'used_percentage')
$cost         = Get-Prop $data @('cost', 'total_cost_usd')
$linesAdded   = Get-Prop $data @('cost', 'total_lines_added')
$linesRemoved = Get-Prop $data @('cost', 'total_lines_removed')

# Quirk (model), tagged with the theme's ultra-line when stamina is high
$quirkPart = "$BOLD$C_QUIRK$QUIRK_ICON $model$RESET"

# Rank (hero XP/level from gain-xp.ps1's Stop hook — grows one tick per finished
# turn). Missing/unreadable state file just means "not trained yet": Lv1, empty bar.
$rankStateFile = Join-Path $PSScriptRoot 'mha-statusline-state.json'
$rankState = $null
if (Test-Path $rankStateFile) {
    try { $rankState = Get-Content -Raw $rankStateFile | ConvertFrom-Json } catch { $rankState = $null }
}
$rankLevel = if ($rankState -and $rankState.level) { [int]$rankState.level } else { 1 }
$rankXp    = if ($rankState -and $null -ne $rankState.xp) { [int]$rankState.xp } else { 0 }
$rankXpToNext = Get-XpToNext $rankLevel
$rankTitle = Get-RankTitle $rankLevel

$barSegments = 10
$rankFilled = [math]::Min($barSegments, [math]::Floor(($rankXp / [double]$rankXpToNext) * $barSegments))
$rankBar = ('▰' * $rankFilled) + ('▱' * ($barSegments - $rankFilled))

$rankPart = "$C_QUIRK🎓 $rankTitle Lv$rankLevel  $rankBar $rankXp/$rankXpToNext$RESET"

# Agency (dir + branch)
$agencyPart = "$C_AGENCY🏫 $dirName$RESET"
if ($branch) { $agencyPart += " $C_BRANCH⚡$branch$RESET" }

# Everything below collects into $parts for the third line (session stats) —
# split across three lines total so nothing gets width-truncated by the
# terminal: identity, hero rank, session stats.
$parts = New-Object System.Collections.Generic.List[string]

# Stamina (context remaining %)
if ($null -ne $remaining) {
    $ctxVal = [math]::Round([double]$remaining)
    $staColor = $C_STA_OK
    if ($ctxVal -lt 20) { $staColor = $C_STA_BAD }
    elseif ($ctxVal -lt 50) { $staColor = $C_STA_WARN }
    $staPart = "${staColor}🔋 Stamina:$ctxVal%$RESET"
    if ($ctxVal -ge 80) { $staPart += " $BOLD$C_STA_OK $ULTRA$RESET" }
    $parts.Add($staPart)
}

# Cooldown (5h/7d rate limits)
if ($null -ne $five -or $null -ne $week) {
    $cooldownStr = "$C_COOLDOWN⏱ "
    if ($null -ne $five) { $cooldownStr += "5h:$([math]::Round([double]$five))%" }
    if ($null -ne $week) {
        if ($null -ne $five) { $cooldownStr += ' ' }
        $cooldownStr += "7d:$([math]::Round([double]$week))%"
    }
    $cooldownStr += $RESET
    $parts.Add($cooldownStr)
}

# Cost
if ($null -ne $cost) {
    $costStr = [double]$cost
    $parts.Add("$C_COST🪙 `$$($costStr.ToString('0.00'))$RESET")
}

# Combat log (+/- lines)
if ($null -ne $linesAdded -or $null -ne $linesRemoved) {
    $added = if ($linesAdded) { [int]$linesAdded } else { 0 }
    $removed = if ($linesRemoved) { [int]$linesRemoved } else { 0 }
    $parts.Add("$C_ADD+$added$RESET $C_DEL-$removed$RESET")
}

$separator = " $C_BOLT⚡$RESET "

# Three lines: identity (Quirk + Agency), hero Rank, session stats. Each line
# ends in $RESET already (every segment closes its own color), so stacking
# them with newlines is safe per Claude Code's multi-line statusline support.
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("$quirkPart$separator$agencyPart")
$lines.Add($rankPart)
if ($parts.Count -gt 0) { $lines.Add(($parts -join $separator)) }

$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write(($lines -join "`n"))
$stdoutWriter.Flush()
