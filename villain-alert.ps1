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

# Icon+hero-name-only lookup -- deliberately NOT the full color catalogue
# from statusline.ps1 (OSC 9 desktop notifications are plain text, colors
# don't apply here). Kept in sync with statusline.ps1's $Themes roster --
# regenerate by extracting each theme's QuirkIcon/Hero if that roster grows.
$HeroNames = @{
    'aizawa' = @{ Icon = '🧣'; Name = 'Eraser Head' }
    'allforone' = @{ Icon = '👑'; Name = 'All For One' }
    'allmight' = @{ Icon = '💪'; Name = 'All Might' }
    'aoyama' = @{ Icon = '💫'; Name = "Can't Stop Twinkling" }
    'ashido' = @{ Icon = '🧪'; Name = 'Pinky' }
    'asui' = @{ Icon = '🐸'; Name = 'Froppy' }
    'awase' = @{ Icon = '🔧'; Name = 'Welder' }
    'bakugo' = @{ Icon = '💥'; Name = 'Dynamight' }
    'banjo' = @{ Icon = '〰️'; Name = 'Banjo' }
    'bestjeanist' = @{ Icon = '🧵'; Name = 'Best Jeanist' }
    'bondo' = @{ Icon = '🧴'; Name = 'Plamo' }
    'brucelee' = @{ Icon = '🥋'; Name = 'Bruce Lee' }
    'burnin' = @{ Icon = '🔥'; Name = 'Burnin' }
    'cementoss' = @{ Icon = '🧱'; Name = 'Cementoss' }
    'dabi' = @{ Icon = '🔥'; Name = 'Dabi' }
    'deku' = @{ Icon = '✊'; Name = 'Deku' }
    'ectoplasm' = @{ Icon = '👥'; Name = 'Ectoplasm' }
    'edgeshot' = @{ Icon = '🥷'; Name = 'Edgeshot' }
    'en' = @{ Icon = '💨'; Name = 'En' }
    'endeavor' = @{ Icon = '🔥'; Name = 'Endeavor' }
    'fatgum' = @{ Icon = '🍔'; Name = 'Fat Gum' }
    'fukidashi' = @{ Icon = '💬'; Name = 'Comicman' }
    'garaki' = @{ Icon = '🧪'; Name = 'Dr. Garaki' }
    'gentle' = @{ Icon = '🎩'; Name = 'Gentle Criminal' }
    'geten' = @{ Icon = '🧊'; Name = 'Geten' }
    'grantorino' = @{ Icon = '👴'; Name = 'Gran Torino' }
    'gunhead' = @{ Icon = '🥊'; Name = 'Gunhead' }
    'hagakure' = @{ Icon = '🫥'; Name = 'Invisible Girl' }
    'hawks' = @{ Icon = '🪶'; Name = 'Hawks' }
    'honenuki' = @{ Icon = '🟫'; Name = 'Mudman' }
    'hounddog' = @{ Icon = '🐕'; Name = 'Hound Dog' }
    'iida' = @{ Icon = '🦿'; Name = 'Ingenium' }
    'jiro' = @{ Icon = '🎧'; Name = 'Earphone Jack' }
    'kaibara' = @{ Icon = '🌪️'; Name = 'Spiral' }
    'kamakiri' = @{ Icon = '🦗'; Name = 'Jack Mantis' }
    'kaminari' = @{ Icon = '⚡'; Name = 'Chargezuma' }
    'kamuiwoods' = @{ Icon = '🌳'; Name = 'Kamui Woods' }
    'kendo' = @{ Icon = '👊'; Name = 'Battle Fist' }
    'kirishima' = @{ Icon = '🪨'; Name = 'Red Riot' }
    'koda' = @{ Icon = '🦉'; Name = 'Anima' }
    'kodai' = @{ Icon = '📏'; Name = 'Rule' }
    'komori' = @{ Icon = '🍄'; Name = 'Shemage' }
    'kudo' = @{ Icon = '⚙️'; Name = 'Kudo' }
    'kurogiri' = @{ Icon = '🌀'; Name = 'Kurogiri' }
    'kuroiro' = @{ Icon = '⚫'; Name = 'Vantablack' }
    'labrava' = @{ Icon = '💕'; Name = 'La Brava' }
    'ladynagant' = @{ Icon = '🎯'; Name = 'Lady Nagant' }
    'magne' = @{ Icon = '🧲'; Name = 'Magne' }
    'mandalay' = @{ Icon = '🐆'; Name = 'Mandalay' }
    'manual' = @{ Icon = '💧'; Name = 'Manual' }
    'midnight' = @{ Icon = '🌙'; Name = 'Midnight' }
    'mineta' = @{ Icon = '🟣'; Name = 'Grape Juice' }
    'mirio' = @{ Icon = '👻'; Name = 'Lemillion' }
    'mirko' = @{ Icon = '🐰'; Name = 'Mirko' }
    'momo' = @{ Icon = '✨'; Name = 'Creati' }
    'monoma' = @{ Icon = '🪞'; Name = 'Phantom Thief' }
    'moonfish' = @{ Icon = '🦈'; Name = 'Moonfish' }
    'mrcompress' = @{ Icon = '🎪'; Name = 'Mr. Compress' }
    'mtlady' = @{ Icon = '🗼'; Name = 'Mt. Lady' }
    'muscular' = @{ Icon = '💪'; Name = 'Muscular' }
    'mustard' = @{ Icon = '☠️'; Name = 'Mustard' }
    'nana' = @{ Icon = '🪽'; Name = 'Nana Shimura' }
    'nejire' = @{ Icon = '🌀'; Name = 'Nejire-chan' }
    'nezu' = @{ Icon = '🐭'; Name = 'Nezu' }
    'nighteye' = @{ Icon = '👁️'; Name = 'Sir Nighteye' }
    'ojiro' = @{ Icon = '🐒'; Name = 'Tailman' }
    'overhaul' = @{ Icon = '🧤'; Name = 'Overhaul' }
    'pixiebob' = @{ Icon = '🪨'; Name = 'Pixie-Bob' }
    'powerloader' = @{ Icon = '⛏️'; Name = 'Power Loader' }
    'presentmic' = @{ Icon = '🎤'; Name = 'Present Mic' }
    'ragdoll' = @{ Icon = '🔍'; Name = 'Ragdoll' }
    'rappa' = @{ Icon = '🥋'; Name = 'Rappa' }
    'recoverygirl' = @{ Icon = '💊'; Name = 'Recovery Girl' }
    'redestro' = @{ Icon = '💰'; Name = 'Re-Destro' }
    'rin' = @{ Icon = '🐉'; Name = 'Dragon Shroud' }
    'rocklock' = @{ Icon = '🔒'; Name = 'Rock Lock' }
    'ryukyu' = @{ Icon = '🐲'; Name = 'Ryukyu' }
    'sato' = @{ Icon = '🍬'; Name = 'Sugarman' }
    'selkie' = @{ Icon = '🦭'; Name = 'Selkie' }
    'sero' = @{ Icon = '📼'; Name = 'Cellophane' }
    'shigaraki' = @{ Icon = '🖐️'; Name = 'Shigaraki' }
    'shinomori' = @{ Icon = '🥷'; Name = 'Shinomori' }
    'shinzo' = @{ Icon = '🧠'; Name = 'NightHide' }
    'shiozaki' = @{ Icon = '🌿'; Name = 'Vine' }
    'shishida' = @{ Icon = '🦁'; Name = 'Gevaudan' }
    'shoda' = @{ Icon = '💣'; Name = 'Mines' }
    'shoji' = @{ Icon = '🐙'; Name = 'Tentacole' }
    'skeptic' = @{ Icon = '🎮'; Name = 'Skeptic' }
    'snipe' = @{ Icon = '🔫'; Name = 'Snipe' }
    'spinner' = @{ Icon = '🦎'; Name = 'Spinner' }
    'stain' = @{ Icon = '🗡️'; Name = 'Stain' }
    'starandstripe' = @{ Icon = '🇺🇸'; Name = 'Star and Stripe' }
    'tamaki' = @{ Icon = '🍽️'; Name = 'Suneater' }
    'tetsutetsu' = @{ Icon = '🔩'; Name = 'Real Steel' }
    'thirteen' = @{ Icon = '🕳️'; Name = 'Thirteen' }
    'tiger' = @{ Icon = '🐯'; Name = 'Tiger' }
    'todoroki' = @{ Icon = '❄️'; Name = 'Shoto' }
    'toga' = @{ Icon = '🩸'; Name = 'Toga' }
    'tokage' = @{ Icon = '🦎'; Name = 'Lizardy' }
    'tokoyami' = @{ Icon = '🌑'; Name = 'Tsukuyomi' }
    'tsuburaba' = @{ Icon = '🫧'; Name = 'Tsuburaba' }
    'tsunotori' = @{ Icon = '🦄'; Name = 'Rocketti' }
    'twice' = @{ Icon = '🎭'; Name = 'Twice' }
    'uraraka' = @{ Icon = '🪐'; Name = 'Uravity' }
    'uwabami' = @{ Icon = '🐍'; Name = 'Uwabami' }
    'vladking' = @{ Icon = '🩸'; Name = 'Vlad King' }
    'yanagi' = @{ Icon = '🔮'; Name = 'Emily' }
    'yoichi' = @{ Icon = '🕊️'; Name = 'Yoichi' }
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
