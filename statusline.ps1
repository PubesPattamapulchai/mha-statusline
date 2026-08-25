# Claude Code statusline — My Hero Academia theme (pure PowerShell, no node/jq/installs required)
# Quirk (model) | Agency (dir + git branch) | Stamina (ctx remaining %) | Cooldown (5h/7d rate limits) | Cost | Combat log (+/- lines)
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
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

$RESET       = Ansi 0
$BOLD        = Ansi 1
$C_QUIRK     = Ansi 92   # UA green — model / "Quirk"
$C_AGENCY    = Ansi 97   # white — dir
$C_BRANCH    = Ansi 91   # hero red — git branch
$C_STA_OK    = Ansi 92   # stamina full — green
$C_STA_WARN  = Ansi 93   # stamina low — gold
$C_STA_BAD   = Ansi 91   # stamina critical — red
$C_COOLDOWN  = Ansi 96   # cyan — rate limits
$C_COST      = Ansi 93   # gold — cost
$C_ADD       = Ansi 92
$C_DEL       = Ansi 91
$C_BOLT      = Ansi 93   # separator lightning bolt, gold/dim

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

$parts = New-Object System.Collections.Generic.List[string]

# Quirk (model), tagged PLUS ULTRA! when stamina is high
$quirkPart = "$BOLD$C_QUIRK`💥 $model$RESET"
$parts.Add($quirkPart)

# Agency (dir + branch)
$agencyPart = "$C_AGENCY`🏫 $dirName$RESET"
if ($branch) { $agencyPart += " $C_BRANCH⚡$branch$RESET" }
$parts.Add($agencyPart)

# Stamina (context remaining %)
if ($null -ne $remaining) {
    $ctxVal = [math]::Round([double]$remaining)
    $staColor = $C_STA_OK
    if ($ctxVal -lt 20) { $staColor = $C_STA_BAD }
    elseif ($ctxVal -lt 50) { $staColor = $C_STA_WARN }
    $staPart = "${staColor}🔋 Stamina:$ctxVal%$RESET"
    if ($ctxVal -ge 80) { $staPart += " $BOLD$C_STA_OK PLUS ULTRA!$RESET" }
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
    $parts.Add("$C_COST`🪙 `$$($costStr.ToString('0.00'))$RESET")
}

# Combat log (+/- lines)
if ($null -ne $linesAdded -or $null -ne $linesRemoved) {
    $added = if ($linesAdded) { [int]$linesAdded } else { 0 }
    $removed = if ($linesRemoved) { [int]$linesRemoved } else { 0 }
    $parts.Add("$C_ADD+$added$RESET $C_DEL-$removed$RESET")
}

$separator = " $C_BOLT⚡$RESET "
[Console]::Out.Write(($parts -join $separator))
