# Claude Code "Notification" hook -- reskins a subset of notifications as
# "Villain Attack!" alerts, themed to whichever mha-statusline hero theme is
# active.
#
# Notification hooks are special: per Claude Code's docs, stdout/stderr and
# exit code are ALL ignored for this event -- there is no way to print
# visible text the way other hooks can. The only supported channel for a
# user-visible side effect is `hookSpecificOutput.terminalSequence` in the
# hook's JSON stdout, which Claude Code forwards straight to the terminal as
# raw bytes (bell / OSC sequences). So: a bell, plus an OSC 9 desktop
# notification carrying the themed text. No plain "print a message" path
# exists for this event -- that's a hard constraint of the hook contract,
# not a design choice here.
#
# install.ps1 registers this against a matcher of just the "Claude actually
# needs you" notification types (permission_prompt, agent_needs_input,
# idle_prompt) -- not every notification type -- so this only fires for
# things worth interrupting you for.
$ErrorActionPreference = 'SilentlyContinue'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8NoBom)
$raw = $stdinReader.ReadToEnd()
try { $data = $raw | ConvertFrom-Json } catch { $data = $null }

$notificationType = if ($data) { $data.notification_type } else { $null }
$notificationMessage = if ($data) { $data.notification_message } else { $null }
if (-not $notificationMessage) { $notificationMessage = 'Claude needs your input.' }

# Small icon+hero-name-only lookup -- deliberately NOT the full color
# catalogue from statusline.ps1 (OSC 9 desktop notifications are plain text,
# colors don't apply here, and duplicating 22 entries' worth of ANSI codes
# for a feature that can't render them would just be drift-risk for nothing).
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

$themeKey = $env:MHA_STATUSLINE_THEME
if (-not $themeKey) {
    $themeFile = Join-Path $PSScriptRoot 'mha-theme.txt'
    if (Test-Path $themeFile) { $themeKey = Get-Content -Raw $themeFile }
}
if ($themeKey) { $themeKey = $themeKey.Trim([char]0xFEFF, ' ', "`r", "`n").ToLowerInvariant() }
if (-not $themeKey -or -not $HeroNames.ContainsKey($themeKey)) { $themeKey = 'deku' }
$hero = $HeroNames[$themeKey]

$prefix = switch ($notificationType) {
    'idle_prompt' { "💤 $($hero.Name) is on standby" }
    default       { "🚨 VILLAIN SIGHTED — $($hero.Icon) $($hero.Name), your call" }
}
$text = "$prefix`: $notificationMessage"

# OSC 9 (desktop notification) is widely supported (Windows Terminal,
# iTerm2, ConEmu); terminals that don't recognize it just no-op harmlessly.
# BEL first as a fallback for terminals that support only the plain bell.
$BEL = [char]7
$ESC = [char]27
$terminalSequence = "$BEL$ESC]9;$text$BEL"

$output = [PSCustomObject]@{
    hookSpecificOutput = [PSCustomObject]@{
        hookEventName    = 'Notification'
        terminalSequence = $terminalSequence
    }
}
$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write(($output | ConvertTo-Json -Depth 5 -Compress))
$stdoutWriter.Flush()
