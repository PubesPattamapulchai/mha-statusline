# My Hero Academia statusline — pure PowerShell, no node/jq/installs required.
# Wired into Claude Code's statusLine setting by default, but runs standalone
# too (shell prompt hook, manual invocation) for tools with no such hook of
# their own — see install.ps1 -Target Shell for Codex/local-LLM/plain-shell use.
# One line, kept minimal: Quirk (model) | Agency (dir) | Rank (hero level,
# career-stage) | Cooldown (5h/7d rate limits, Claude Code only)
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

# Claude Code always pipes a JSON payload in on stdin. Run standalone instead
# (a shell prompt hook, a manual test, Codex/local-LLM terminals that have no
# such payload) and stdin is the interactive console, not a pipe — reading it
# would block forever waiting for input that will never come. Only attempt
# the read when something is actually redirected in.
if ([Console]::IsInputRedirected) {
    $stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8NoBom)
    $raw = $stdinReader.ReadToEnd()
    try { $data = $raw | ConvertFrom-Json } catch { $data = $null }
} else {
    $data = $null
}

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
# finally the JP Hero Billboard Chart counting down toward #1. The chart
# countdown (Lv40-100, #300-#1) is two curves stitched together, not one:
#   - Lv40-95 covers #300 down to #10 *linearly* (constant ~5.3 ranks per
#     level) — a straight line has no flat spot anywhere along it, so
#     resolution stays even the whole way instead of bunching up early and
#     going coarse as it nears the Lv95 handoff the way a power curve
#     (exponent > 1) would.
#   - Lv95-100 then spreads the last 9 ranks across that final stretch
#     with exponent 0.4, whose slope keeps *growing* as Lv approaches 100
#     instead of flattening out — so #1 through #10 stay distinguishable
#     down to fractions of a level instead of collapsing onto the same
#     rank the way a straight line or a fast-then-slow curve would right
#     at the top.
# Every power curve with exponent > 1 is fast-then-flat: great at one end,
# coarse at the other. Linear is the only shape with no coarse end at all,
# which is why the first segment uses it instead of chasing a fast start
# and paying for it with a dead zone right before the handoff.
function Get-RankAbbrev([double]$level) {
    if ($level -ge 40) {
        $t = ($level - 40) / 60.0        # 0 at Lv40, 1 at Lv100
        $tBreak = (95.0 - 40) / 60.0     # breakpoint: Lv95 == rank #10
        if ($t -le $tBreak) {
            $s = $t / $tBreak
            $rank = 10 + 290 * (1 - $s)
        } else {
            $u = ($t - $tBreak) / (1 - $tBreak)
            $rank = 1 + 9 * [math]::Pow(1 - $u, 0.4)
        }
        $rank = [math]::Max(1, [math]::Min(300, [math]::Round($rank)))
        return "#$rank"
    }
    if ($level -ge 30) { return 'Agency Founder' }
    if ($level -ge 20) { return 'Sidekick' }
    if ($level -ge 15) { return 'License' }
    if ($level -ge 10) { return 'Y3' }
    if ($level -ge 5)  { return 'Y2' }
    return 'Y1'
}

# Quirk Registry: boxed "LEVEL UP!" banner shown for one render right after
# your live level crosses a multiple-of-10 boundary upward. Rank itself
# accumulates nothing, but "did I just cross a boundary" is inherently a
# before/after question, so this is the one bonus feature that remembers
# anything between renders — see the small last-seen-level file read/written
# further down. Box width adapts to the longest hero name so e.g. "Can't
# Stop Twinkling" doesn't get clipped.
function Get-LevelUpBanner([string]$Icon, [string]$HeroName, [int]$Level, [string]$StageAbbrev, [string]$Color, [string]$Reset) {
    $contentLines = @(
        "LEVEL UP!  Lv$Level"
        "$Icon $($HeroName.ToUpper())"
        "$StageAbbrev unlocked"
    )
    $innerWidth = ($contentLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $boxWidth = $innerWidth + 4
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("$Color╔$('═' * $boxWidth)╗$Reset")
    foreach ($cl in $contentLines) {
        $padTotal = $boxWidth - $cl.Length
        $padLeft = [math]::Floor($padTotal / 2)
        $padRight = $padTotal - $padLeft
        $lines.Add("$Color║$Reset" + (' ' * $padLeft) + $cl + (' ' * $padRight) + "$Color║$Reset")
    }
    $lines.Add("$Color╚$('═' * $boxWidth)╝$Reset")
    return $lines
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
        Label     = 'All Might (Yagi Toshinori)'
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
    # ---- Rest of Class 1-B ----------------------------------------------
    'monoma' = @{
        Label     = 'Monoma (Neito)'
        QuirkIcon = '🪞'
        Quirk     = Ansi256 51    # Copy — mirror cyan
        Agency    = Ansi 97
        Cooldown  = Ansi256 87
        Hero      = 'Phantom Thief'
    }
    'kendo' = @{
        Label     = 'Kendo (Itsuka)'
        QuirkIcon = '👊'
        Quirk     = Ansi256 173   # Big Fist — tan gi
        Agency    = Ansi 97
        Cooldown  = Ansi256 215
        Hero      = 'Battle Fist'
    }
    'tetsutetsu' = @{
        Label     = 'Tetsutetsu Tetsutetsu'
        QuirkIcon = '🔩'
        Quirk     = Ansi256 249   # Steel — chrome gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 255
        Hero      = 'Real Steel'
    }
    'tokage' = @{
        Label     = 'Tokage (Setsuna)'
        QuirkIcon = '🦎'
        Quirk     = Ansi256 118   # Lizard Tail Splitter — green
        Agency    = Ansi 97
        Cooldown  = Ansi256 154
        Hero      = 'Lizardy'
    }
    'shiozaki' = @{
        Label     = 'Shiozaki (Ibara)'
        QuirkIcon = '🌿'
        Quirk     = Ansi256 28    # Vines — deep green
        Agency    = Ansi 97
        Cooldown  = Ansi256 84
        Hero      = 'Vine'
    }
    'kuroiro' = @{
        Label     = 'Kuroiro (Shihai)'
        QuirkIcon = '⚫'
        Quirk     = Ansi256 236   # Black — near-black
        Agency    = Ansi 97
        Cooldown  = Ansi256 240
        Hero      = 'Vantablack'
    }
    'kamakiri' = @{
        Label     = 'Kamakiri (Togaru)'
        QuirkIcon = '🦗'
        Quirk     = Ansi256 34    # Razor Sharp — mantis green
        Agency    = Ansi 97
        Cooldown  = Ansi256 82
        Hero      = 'Jack Mantis'
    }
    'komori' = @{
        Label     = 'Komori (Kinoko)'
        QuirkIcon = '🍄'
        Quirk     = Ansi256 211   # Mushroom — pink hair/spores
        Agency    = Ansi 97
        Cooldown  = Ansi256 223
        Hero      = 'Shemage'
    }
    # ---- Rest of Class 1-B (rounds the class out to all 20) --------------
    'awase' = @{
        Label     = 'Awase (Yosetsu)'
        QuirkIcon = '🔧'
        Quirk     = Ansi256 214   # Weld — welding-spark orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 220
        Hero      = 'Welder'
    }
    'bondo' = @{
        Label     = 'Bondo (Kojiro)'
        QuirkIcon = '🧴'
        Quirk     = Ansi256 224   # Cemedine — glue tan
        Agency    = Ansi 97
        Cooldown  = Ansi256 230
        Hero      = 'Plamo'
    }
    'fukidashi' = @{
        Label     = 'Fukidashi (Manga)'
        QuirkIcon = '💬'
        Quirk     = Ansi256 226   # Comic — speech-bubble yellow
        Agency    = Ansi 97
        Cooldown  = Ansi256 231
        Hero      = 'Comicman'
    }
    'honenuki' = @{
        Label     = 'Honenuki (Juzo)'
        QuirkIcon = '🟫'
        Quirk     = Ansi256 94    # Softening — mud brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 137
        Hero      = 'Mudman'
    }
    'kaibara' = @{
        Label     = 'Kaibara (Sen)'
        QuirkIcon = '🌪️'
        Quirk     = Ansi256 172   # Gyrate — drill orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 208
        Hero      = 'Spiral'
    }
    'kodai' = @{
        Label     = 'Kodai (Yui)'
        QuirkIcon = '📏'
        Quirk     = Ansi256 111   # Size — soft blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 153
        Hero      = 'Rule'
    }
    'rin' = @{
        Label     = 'Rin (Hiryu)'
        QuirkIcon = '🐉'
        Quirk     = Ansi256 25    # Scales — dragon blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 32
        Hero      = 'Dragon Shroud'
    }
    'shishida' = @{
        Label     = 'Shishida (Jurota)'
        QuirkIcon = '🦁'
        Quirk     = Ansi256 130   # Beast — feral brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 94
        Hero      = 'Gevaudan'
    }
    'shoda' = @{
        Label     = 'Shoda (Nirengeki)'
        QuirkIcon = '💣'
        Quirk     = Ansi256 166   # Twin Impact — blast orange-red
        Agency    = Ansi 97
        Cooldown  = Ansi256 202
        Hero      = 'Mines'
    }
    'tsuburaba' = @{
        Label     = 'Tsuburaba (Kosei)'
        QuirkIcon = '🫧'
        Quirk     = Ansi256 195   # Solid Air — pale blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 159
        Hero      = 'Tsuburaba'
    }
    'tsunotori' = @{
        Label     = 'Tsunotori (Pony)'
        QuirkIcon = '🦄'
        Quirk     = Ansi256 219   # Horn Cannon — pastel pink
        Agency    = Ansi 97
        Cooldown  = Ansi256 225
        Hero      = 'Rocketti'
    }
    'yanagi' = @{
        Label     = 'Yanagi (Reiko)'
        QuirkIcon = '🔮'
        Quirk     = Ansi256 141   # Poltergeist — psychic purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 183
        Hero      = 'Emily'
    }
    # ---- U.A.'s "Big 3" --------------------------------------------------
    'mirio' = @{
        Label     = 'Togata (Mirio)'
        QuirkIcon = '👻'
        Quirk     = Ansi256 220   # Permeation — gold hero suit
        Agency    = Ansi 97
        Cooldown  = Ansi256 226
        Hero      = 'Lemillion'
    }
    'tamaki' = @{
        Label     = 'Amajiki (Tamaki)'
        QuirkIcon = '🍽️'
        Quirk     = Ansi256 97    # Manifest — shy indigo
        Agency    = Ansi 97
        Cooldown  = Ansi256 60
        Hero      = 'Suneater'
    }
    'nejire' = @{
        Label     = 'Hado (Nejire)'
        QuirkIcon = '🌀'
        Quirk     = Ansi256 39    # Wave Motion — blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 45
        Hero      = 'Nejire-chan'
    }
    # ---- One For All lineage (past holders before All Might/Deku) --------
    'yoichi' = @{
        Label     = 'Shigaraki (Yoichi)'
        QuirkIcon = '🕊️'
        Quirk     = Ansi256 223   # Quirk Bestowal — 1st user, soft gold
        Agency    = Ansi 97
        Cooldown  = Ansi256 230
        Hero      = 'Yoichi'
    }
    'kudo' = @{
        Label     = 'Kudo (Toshitsugu)'
        QuirkIcon = '⚙️'
        Quirk     = Ansi256 67    # Gearshift — 2nd user, mechanical blue-gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 103
        Hero      = 'Kudo'
    }
    'brucelee' = @{
        Label     = 'Bruce Lee'
        QuirkIcon = '🥋'
        Quirk     = Ansi256 214   # Fa Jin — 3rd user, explosive orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 208
        Hero      = 'Bruce Lee'
    }
    'shinomori' = @{
        Label     = 'Shinomori (Hikage)'
        QuirkIcon = '🥷'
        Quirk     = Ansi256 54    # Danger Sense — 4th user, stealth purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 96
        Hero      = 'Shinomori'
    }
    'banjo' = @{
        Label     = 'Banjo (Daigoro)'
        QuirkIcon = '〰️'
        Quirk     = Ansi256 55    # Blackwhip — 5th user, black-purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 129
        Hero      = 'Banjo'
    }
    'en' = @{
        Label     = 'Tayutai (En)'
        QuirkIcon = '💨'
        Quirk     = Ansi256 96    # Smokescreen — 6th user, smoke purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 140
        Hero      = 'En'
    }
    'nana' = @{
        Label     = 'Shimura (Nana)'
        QuirkIcon = '🪽'
        Quirk     = Ansi256 130   # Float — 7th user, All Might's mentor, warm brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 216
        Hero      = 'Nana Shimura'
    }
    # ---- More U.A. faculty -------------------------------------------------
    'presentmic' = @{
        Label     = 'Present Mic (Yamada Hizashi)'
        QuirkIcon = '🎤'
        Quirk     = Ansi256 226   # Voice — radio-DJ yellow
        Agency    = Ansi 97
        Cooldown  = Ansi256 220
        Hero      = 'Present Mic'
    }
    'midnight' = @{
        Label     = 'Midnight (Kayama Nemuri)'
        QuirkIcon = '🌙'
        Quirk     = Ansi256 129   # Somnambulist — purple
        Agency    = Ansi 97
        Cooldown  = Ansi256 93
        Hero      = 'Midnight'
    }
    'vladking' = @{
        Label     = 'Vlad King (Kan Sekijiro)'
        QuirkIcon = '🩸'
        Quirk     = Ansi256 88    # Blood Control — dark red
        Agency    = Ansi 97
        Cooldown  = Ansi256 124
        Hero      = 'Vlad King'
    }
    'cementoss' = @{
        Label     = 'Cementoss (Ishiyama Ken)'
        QuirkIcon = '🧱'
        Quirk     = Ansi256 250   # Cement — concrete gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 246
        Hero      = 'Cementoss'
    }
    'powerloader' = @{
        Label     = 'Power Loader (Maijima Higari)'
        QuirkIcon = '⛏️'
        Quirk     = Ansi256 202   # Metal Bulkup — mining-suit orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 214
        Hero      = 'Power Loader'
    }
    'nezu' = @{
        Label     = 'Nezu'
        QuirkIcon = '🐭'
        Quirk     = Ansi256 230   # High Specs — cream fur
        Agency    = Ansi 97
        Cooldown  = Ansi256 223
        Hero      = 'Nezu'
    }
    'recoverygirl' = @{
        Label     = 'Recovery Girl (Shuzenji Chiyo)'
        QuirkIcon = '💊'
        Quirk     = Ansi256 217   # Heal — soft pink
        Agency    = Ansi 97
        Cooldown  = Ansi256 224
        Hero      = 'Recovery Girl'
    }
    'thirteen' = @{
        Label     = 'Thirteen (Kurose Anan)'
        QuirkIcon = '🕳️'
        Quirk     = Ansi256 235   # Black Hole — void black
        Agency    = Ansi 97
        Cooldown  = Ansi256 57
        Hero      = 'Thirteen'
    }
    'ectoplasm' = @{
        Label     = 'Ectoplasm'
        QuirkIcon = '👥'
        Quirk     = Ansi256 79    # Clones — spectral teal
        Agency    = Ansi 97
        Cooldown  = Ansi256 43
        Hero      = 'Ectoplasm'
    }
    'snipe' = @{
        Label     = 'Snipe'
        QuirkIcon = '🔫'
        Quirk     = Ansi256 130   # Homing — cowboy brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 172
        Hero      = 'Snipe'
    }
    'hounddog' = @{
        Label     = 'Hound Dog (Inui Ryo)'
        QuirkIcon = '🐕'
        Quirk     = Ansi256 130   # Dog — canine tan
        Agency    = Ansi 97
        Cooldown  = Ansi256 172
        Hero      = 'Hound Dog'
    }
    # ---- Named sidekicks / mentor heroes --------------------------------
    'nighteye' = @{
        Label     = 'Sir Nighteye (Sasaki Mirai)'
        QuirkIcon = '👁️'
        Quirk     = Ansi256 22    # Foresight — hero-suit dark green
        Agency    = Ansi 97
        Cooldown  = Ansi256 28
        Hero      = 'Sir Nighteye'
    }
    'selkie' = @{
        Label     = 'Selkie'
        QuirkIcon = '🦭'
        Quirk     = Ansi256 67    # Spotted Seal — seal gray-blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 152
        Hero      = 'Selkie'
    }
    'manual' = @{
        Label     = 'Manual (Mizushima Masaki)'
        QuirkIcon = '💧'
        Quirk     = Ansi256 39    # Water — clear blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 75
        Hero      = 'Manual'
    }
    'uwabami' = @{
        Label     = 'Uwabami'
        QuirkIcon = '🐍'
        Quirk     = Ansi256 135   # Serpentress — kimono purple-gold
        Agency    = Ansi 97
        Cooldown  = Ansi256 178
        Hero      = 'Uwabami'
    }
    'burnin' = @{
        Label     = 'Burnin (Kamiji Moe)'
        QuirkIcon = '🔥'
        Quirk     = Ansi256 202   # Burning Hair — orange-red
        Agency    = Ansi 97
        Cooldown  = Ansi256 208
        Hero      = 'Burnin'
    }
    # ---- Wild, Wild Pussycats (Forest Training Camp mentors) ------------
    'mandalay' = @{
        Label     = 'Sosaki (Shino)'
        QuirkIcon = '🐆'
        Quirk     = Ansi256 172   # Telepath — leopard-print orange-brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 94
        Hero      = 'Mandalay'
    }
    'pixiebob' = @{
        Label     = 'Tsuchikawa (Ryuko)'
        QuirkIcon = '🪨'
        Quirk     = Ansi256 136   # Earth Flow — earthen tan
        Agency    = Ansi 97
        Cooldown  = Ansi256 94
        Hero      = 'Pixie-Bob'
    }
    'ragdoll' = @{
        Label     = 'Shiretoko (Tomoko)'
        QuirkIcon = '🔍'
        Quirk     = Ansi256 218   # Search — cheerful pink
        Agency    = Ansi 97
        Cooldown  = Ansi256 224
        Hero      = 'Ragdoll'
    }
    'tiger' = @{
        Label     = 'Chatora (Yawara)'
        QuirkIcon = '🐯'
        Quirk     = Ansi256 166   # Pliabody — tiger-stripe burnt orange
        Agency    = Ansi 97
        Cooldown  = Ansi256 178
        Hero      = 'Tiger'
    }
    # ---- Pro heroes ----------------------------------------------------
    'endeavor' = @{
        Label     = 'Endeavor (Todoroki Enji)'
        QuirkIcon = '🔥'
        Quirk     = Ansi256 196   # Hellflame — blazing red
        Agency    = Ansi 97
        Cooldown  = Ansi256 202
        Hero      = 'Endeavor'
    }
    'hawks' = @{
        Label     = 'Hawks (Takami Keigo)'
        QuirkIcon = '🪶'
        Quirk     = Ansi256 197   # Fierce Wings — red-gold
        Agency    = Ansi 97
        Cooldown  = Ansi256 220
        Hero      = 'Hawks'
    }
    'mirko' = @{
        Label     = 'Mirko (Usagiyama Rumi)'
        QuirkIcon = '🐰'
        Quirk     = Ansi256 231   # Rabbit — white fur
        Agency    = Ansi 97
        Cooldown  = Ansi256 218
        Hero      = 'Mirko'
    }
    'bestjeanist' = @{
        Label     = 'Best Jeanist (Hakamada Tsunagu)'
        QuirkIcon = '🧵'
        Quirk     = Ansi256 25    # Fiber Master — denim blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 67
        Hero      = 'Best Jeanist'
    }
    'edgeshot' = @{
        Label     = 'Edgeshot (Kamihara Shinya)'
        QuirkIcon = '🥷'
        Quirk     = Ansi256 17    # Ninja — dark navy
        Agency    = Ansi 97
        Cooldown  = Ansi256 24
        Hero      = 'Edgeshot'
    }
    'grantorino' = @{
        Label     = 'Gran Torino (Torino Sorahiko)'
        QuirkIcon = '👴'
        Quirk     = Ansi256 24    # Jet — retired-hero blue-gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 67
        Hero      = 'Gran Torino'
    }
    'mtlady' = @{
        Label     = 'Mt. Lady (Takeyama Yu)'
        QuirkIcon = '🗼'
        Quirk     = Ansi256 220   # Gigantification — hero-suit yellow
        Agency    = Ansi 97
        Cooldown  = Ansi256 226
        Hero      = 'Mt. Lady'
    }
    'kamuiwoods' = @{
        Label     = 'Kamui Woods (Nishiya Shinji)'
        QuirkIcon = '🌳'
        Quirk     = Ansi256 94    # Arbor — bark brown
        Agency    = Ansi 97
        Cooldown  = Ansi256 28
        Hero      = 'Kamui Woods'
    }
    'fatgum' = @{
        Label     = 'Fat Gum (Toyomitsu Taishiro)'
        QuirkIcon = '🍔'
        Quirk     = Ansi256 220   # Fat — hero-jacket yellow
        Agency    = Ansi 97
        Cooldown  = Ansi256 202
        Hero      = 'Fat Gum'
    }
    'ryukyu' = @{
        Label     = 'Ryukyu (Tatsuma Ryuko)'
        QuirkIcon = '🐲'
        Quirk     = Ansi256 25    # Dragon — western-dragon blue
        Agency    = Ansi 97
        Cooldown  = Ansi256 51
        Hero      = 'Ryukyu'
    }
    'gunhead' = @{
        Label     = 'Gunhead'
        QuirkIcon = '🥊'
        Quirk     = Ansi256 94    # gun-arm martial-arts tan
        Agency    = Ansi 97
        Cooldown  = Ansi256 130
        Hero      = 'Gunhead'
    }
    'rocklock' = @{
        Label     = 'Rock Lock (Takagi Ken)'
        QuirkIcon = '🔒'
        Quirk     = Ansi256 240   # Lock Down — gunmetal gray
        Agency    = Ansi 97
        Cooldown  = Ansi256 245
        Hero      = 'Rock Lock'
    }
    'starandstripe' = @{
        Label     = 'Star and Stripe (Bate Cathleen)'
        QuirkIcon = '🇺🇸'
        Quirk     = Ansi256 196   # New Order — stars-and-stripes red
        Agency    = Ansi 97
        Cooldown  = Ansi256 21    # stars-and-stripes blue
        Hero      = 'Star and Stripe'
    }
    # ---- League of Villains (Agency text in red — no hero agency to run) ---
    'shigaraki' = @{
        Label     = 'Shigaraki (Shimura Tomura)'
        QuirkIcon = '🖐️'
        Quirk     = Ansi256 60    # Decay — ashen blue-gray
        Agency    = Ansi 91
        Cooldown  = Ansi256 245
        Hero      = 'Shigaraki'
        Villain   = $true
    }
    'kurogiri' = @{
        Label     = 'Shirakumo (Oboro)'
        QuirkIcon = '🌀'
        Quirk     = Ansi256 96    # Warp Gate — misty violet-black
        Agency    = Ansi 91
        Cooldown  = Ansi256 59
        Hero      = 'Kurogiri'
        Villain   = $true
    }
    'dabi' = @{
        Label     = 'Dabi (Todoroki Touya)'
        QuirkIcon = '🔥'
        Quirk     = Ansi256 33    # Cremation — cold blue flame
        Agency    = Ansi 91
        Cooldown  = Ansi256 27
        Hero      = 'Dabi'
        Villain   = $true
    }
    'toga' = @{
        Label     = 'Toga (Himiko)'
        QuirkIcon = '🩸'
        Quirk     = Ansi256 218   # Transform — blood pink
        Agency    = Ansi 91
        Cooldown  = Ansi256 197
        Hero      = 'Toga'
        Villain   = $true
    }
    'twice' = @{
        Label     = 'Twice (Bubaigawara Jin)'
        QuirkIcon = '🎭'
        Quirk     = Ansi256 51    # Double — bandage cyan
        Agency    = Ansi 91
        Cooldown  = Ansi256 195
        Hero      = 'Twice'
        Villain   = $true
    }
    'mrcompress' = @{
        Label     = 'Mr. Compress (Sako Atsuhiro)'
        QuirkIcon = '🎪'
        Quirk     = Ansi256 124   # Compress — magician red
        Agency    = Ansi 91
        Cooldown  = Ansi256 231
        Hero      = 'Mr. Compress'
        Villain   = $true
    }
    'spinner' = @{
        Label     = 'Spinner (Iguchi Shuichi)'
        QuirkIcon = '🦎'
        Quirk     = Ansi256 88    # Gecko — scaly red
        Agency    = Ansi 91
        Cooldown  = Ansi256 22
        Hero      = 'Spinner'
        Villain   = $true
    }
    'overhaul' = @{
        Label     = 'Overhaul (Chisaki Kai)'
        QuirkIcon = '🧤'
        Quirk     = Ansi256 178   # Overhaul — plague-mask gold
        Agency    = Ansi 91
        Cooldown  = Ansi256 236
        Hero      = 'Overhaul'
        Villain   = $true
    }
    'stain' = @{
        Label     = 'Stain (Akaguro Chizome)'
        QuirkIcon = '🗡️'
        Quirk     = Ansi256 160   # Bloodcurdle — bandage red
        Agency    = Ansi 91
        Cooldown  = Ansi256 52
        Hero      = 'Stain'
        Villain   = $true
    }
    'allforone' = @{
        Label     = 'Shigaraki (Zen)'
        QuirkIcon = '👑'
        Quirk     = Ansi256 54    # All For One — imperial purple-black
        Agency    = Ansi 91
        Cooldown  = Ansi256 236
        Hero      = 'All For One'
        Villain   = $true
    }
    'muscular' = @{
        Label     = 'Imasuji (Goto)'
        QuirkIcon = '💪'
        Quirk     = Ansi256 204   # Muscle Augmentation — veiny pink-red
        Agency    = Ansi 91
        Cooldown  = Ansi256 88
        Hero      = 'Muscular'
        Villain   = $true
    }
    'magne' = @{
        Label     = 'Hikiishi (Kenji)'
        QuirkIcon = '🧲'
        Quirk     = Ansi256 90    # Magnetism — dark magenta-purple
        Agency    = Ansi 91
        Cooldown  = Ansi256 127
        Hero      = 'Magne'
        Villain   = $true
    }
    'geten' = @{
        Label     = 'Geten'
        QuirkIcon = '🧊'
        Quirk     = Ansi256 159   # Ice Manipulation — pale ice-blue
        Agency    = Ansi 91
        Cooldown  = Ansi256 195
        Hero      = 'Geten'
        Villain   = $true
    }
    'moonfish' = @{
        Label     = 'Moonfish'
        QuirkIcon = '🦈'
        Quirk     = Ansi256 24    # Blade-Tooth — cold steel-blue
        Agency    = Ansi 91
        Cooldown  = Ansi256 250
        Hero      = 'Moonfish'
        Villain   = $true
    }
    'mustard' = @{
        Label     = 'Mustard'
        QuirkIcon = '☠️'
        Quirk     = Ansi256 178   # Gas — toxic mustard yellow
        Agency    = Ansi 91
        Cooldown  = Ansi256 100
        Hero      = 'Mustard'
        Villain   = $true
    }
    'rappa' = @{
        Label     = 'Rappa (Kendo Rappa)'
        QuirkIcon = '🥋'
        Quirk     = Ansi256 124   # Kyoken — Eight Bullets red
        Agency    = Ansi 91
        Cooldown  = Ansi256 52
        Hero      = 'Rappa'
        Villain   = $true
    }
    # ---- Meta Liberation Army --------------------------------------------
    'redestro' = @{
        Label     = 'Re-Destro (Yotsubashi Rikiya)'
        QuirkIcon = '💰'
        Quirk     = Ansi256 88    # Stress — MLA maroon
        Agency    = Ansi 91
        Cooldown  = Ansi256 130
        Hero      = 'Re-Destro'
        Villain   = $true
    }
    'skeptic' = @{
        Label     = 'Skeptic (Chikazoku Tomoyasu)'
        QuirkIcon = '🎮'
        Quirk     = Ansi256 44    # Anthropomorph — screen-glow cyan
        Agency    = Ansi 91
        Cooldown  = Ansi256 80
        Hero      = 'Skeptic'
        Villain   = $true
    }
    # ---- Independent villains / other masterminds ------------------------
    'gentle' = @{
        Label     = 'Gentle Criminal (Tobita Danjuro)'
        QuirkIcon = '🎩'
        Quirk     = Ansi256 29    # Larceny — gentleman teal
        Agency    = Ansi 91
        Cooldown  = Ansi256 222
        Hero      = 'Gentle Criminal'
        Villain   = $true
    }
    'labrava' = @{
        Label     = 'La Brava (Aiba Manami)'
        QuirkIcon = '💕'
        Quirk     = Ansi256 205   # Love — devoted pink
        Agency    = Ansi 91
        Cooldown  = Ansi256 217
        Hero      = 'La Brava'
        Villain   = $true
    }
    'ladynagant' = @{
        Label     = 'Lady Nagant (Tsutsumi Kaina)'
        QuirkIcon = '🎯'
        Quirk     = Ansi256 205   # Rifle — two-tone hair pink
        Agency    = Ansi 91
        Cooldown  = Ansi256 22    # two-tone hair dark green
        Hero      = 'Lady Nagant'
        Villain   = $true
    }
    'garaki' = @{
        Label     = 'Dr. Garaki (Ujiko Daruma)'
        QuirkIcon = '🧪'
        Quirk     = Ansi256 65    # Life Force — sickly lab green
        Agency    = Ansi 91
        Cooldown  = Ansi256 22
        Hero      = 'Dr. Garaki'
        Villain   = $true
    }
}

# Rotation order for auto theme-cycling (see below) — grouped the way the
# theme catalogue above reads (Class 1-A, Class 1-B, Big 3, faculty, pro
# heroes, League of Villains), A-Z by character name within each group
# (Class 1-A: Aoyama first, Yaoyorozu/Momo last since she sorts by surname).
# Not set-theme.ps1's menu order. Plain @{} hashtables in PowerShell don't
# preserve insertion order, so this array is the one place that does.
$ThemeOrder = @(
    # Class 1-A
    'aoyama', 'ashido', 'asui', 'bakugo', 'deku', 'hagakure', 'iida', 'jiro',
    'kaminari', 'kirishima', 'koda', 'mineta', 'ojiro', 'sato', 'sero',
    'shinzo', 'shoji', 'todoroki', 'tokoyami', 'uraraka', 'momo',
    # Class 1-B (all 20)
    'awase', 'bondo', 'fukidashi', 'honenuki', 'kaibara', 'kamakiri',
    'kendo', 'kodai', 'komori', 'kuroiro', 'monoma', 'rin', 'shiozaki',
    'shishida', 'shoda', 'tetsutetsu', 'tokage', 'tsuburaba', 'tsunotori',
    'yanagi',
    # U.A.'s "Big 3"
    'mirio', 'nejire', 'tamaki',
    # One For All lineage (past holders before All Might/Deku)
    'banjo', 'brucelee', 'en', 'kudo', 'nana', 'shinomori', 'yoichi',
    # U.A. faculty (incl. named sidekicks/mentor heroes)
    'aizawa', 'allmight', 'burnin', 'cementoss', 'ectoplasm', 'hounddog',
    'mandalay', 'manual', 'midnight', 'nezu', 'nighteye', 'pixiebob',
    'powerloader', 'presentmic', 'ragdoll', 'recoverygirl', 'selkie', 'snipe',
    'thirteen', 'tiger', 'uwabami', 'vladking',
    # Pro heroes
    'bestjeanist', 'edgeshot', 'endeavor', 'fatgum', 'grantorino',
    'gunhead', 'hawks', 'kamuiwoods', 'mirko', 'mtlady', 'rocklock',
    'ryukyu', 'starandstripe',
    # League of Villains, Meta Liberation Army, and other villains who've
    # carried their own arc
    'allforone', 'dabi', 'garaki', 'gentle', 'geten', 'kurogiri', 'labrava',
    'ladynagant', 'magne', 'moonfish', 'mrcompress', 'muscular', 'mustard',
    'overhaul', 'rappa', 'redestro', 'shigaraki', 'skeptic', 'spinner',
    'stain', 'toga', 'twice'
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

# Real name, pulled out of Label's "Surname (GivenName)" shape — e.g. Label
# 'Iida (Tenya)' with Hero 'Ingenium' gives full RealName 'Iida Tenya'
# (surname + given name, since neither one is just the hero alias repeated
# back). When the surname IS the hero alias (Tsuburaba goes by his own
# surname; Deku/All Might/Present Mic use the codename as the Label prefix
# with the full real name already spelled out in parens), or the given
# name IS the hero alias (Todoroki's hero name is his real first name
# "Shoto"; same for Yoichi/OFA1st), only the other half is new information,
# so just that half is used instead of duplicating the hero name. No
# parens at all means either nothing's known (Label equals Hero — Nezu,
# Snipe, ...), or Label already IS the full real name on its own
# (Tetsutetsu's real name really is "Tetsutetsu Tetsutetsu", so there's
# nothing to split out of parens).
$REAL_NAME = $null
if ($theme.Label -match '^(.*?)\s*\(([^)]+)\)\s*$') {
    $labelPrefix, $realCandidate = $Matches[1], $Matches[2]
    if ($realCandidate -ne $HERO_NAME -and $labelPrefix -ne $HERO_NAME) {
        $REAL_NAME = "$labelPrefix $realCandidate"
    } elseif ($realCandidate -ne $HERO_NAME) {
        $REAL_NAME = $realCandidate
    } elseif ($labelPrefix -ne $HERO_NAME) {
        $REAL_NAME = $labelPrefix
    }
} elseif ($theme.Label -ne $HERO_NAME) {
    $REAL_NAME = $theme.Label
}

$model = Get-Prop $data @('model', 'display_name')
if (-not $model) { $model = '?' }

$dir = Get-Prop $data @('workspace', 'current_dir')
if (-not $dir) { $dir = Get-Prop $data @('cwd') }
if (-not $dir) { $dir = (Get-Location).Path }
$dirName = Split-Path -Leaf $dir
if (-not $dirName) { $dirName = $dir }

$five = Get-Prop $data @('rate_limits', 'five_hour', 'used_percentage')
$week = Get-Prop $data @('rate_limits', 'seven_day', 'used_percentage')

# Quirk (model), tagged with the character's real name (when known) then hero name.
# Skip the hero name if every word in it already showed up in the real name —
# e.g. Nana Shimura's Label is 'Shimura (Nana)' but her Hero field is the
# reversed-order 'Nana Shimura', and Rappa's Hero field 'Rappa' is just the
# surname half of his real name 'Kendo Rappa'. Appending it in those cases
# would just repeat a word we already showed instead of adding one.
$quirkPart = "$BOLD$C_QUIRK$QUIRK_ICON $model$RESET"
if ($REAL_NAME) { $quirkPart += " $BOLD$C_QUIRK$REAL_NAME$RESET" }
if ($HERO_NAME) {
    $realWords = @(); if ($REAL_NAME) { $realWords = $REAL_NAME -split '\s+' }
    $heroWords = $HERO_NAME -split '\s+'
    $heroAddsNothing = $REAL_NAME -and (@($heroWords | Where-Object { $realWords -notcontains $_ })).Count -eq 0
    if (-not $heroAddsNothing) { $quirkPart += " $BOLD$C_QUIRK$HERO_NAME$RESET" }
}

# Agency (current dir)
$agencyPart = "$C_AGENCY$dirName$RESET"

# Rank (hero level) is driven live by this week's usage — the same
# rate_limits.seven_day.used_percentage Claude Code already reports. No
# accumulated state file, no Stop hook: the harder you're leaning on Claude
# this week, the higher your level climbs, and it eases back down as that
# window rolls over. 0-100% maps onto Lv1-100, the full range
# Get-RankAbbrev knows how to label — U.A. student through Agency Founder
# by Lv40, then straight up the JP Hero Billboard Chart (#300 down to #1)
# as usage keeps climbing toward the weekly cap. Missing week data (older
# CLI or a plan without rate limits) just means "no signal yet": Lv1.
#
# Returns both the whole Lv number (for display) and the un-floored
# Continuous value behind it, because raw used_percentage arrives with far
# more precision than a 1-100 integer level can carry (feels especially
# flat right at the top of the chart, where Get-RankAbbrev's curve packs
# nearly a full level into each single rank). Feeding Continuous straight
# into Get-RankAbbrev instead of the floored Lv keeps the #rank readable
# down to whatever fraction of a percent Claude Code actually reports,
# rather than snapping to whichever whole level the percentage rounds into
# — no need to also print the raw weekly % just to explain a rank change.
function Get-LevelFromWeekPct($weekPct) {
    if ($null -eq $weekPct) { return @{ Level = 1; Continuous = 1.0 } }
    $continuous = 1 + [math]::Max(0.0, [math]::Min(100.0, [double]$weekPct)) * 0.99
    $level = [math]::Min(100, [int][math]::Floor($continuous))
    return @{ Level = $level; Continuous = $continuous }
}

# Villains skip this segment entirely — Lv/#rank tracks progress up the
# U.A.-to-Hero-Billboard ladder, and a villain was never on it to begin
# with, so there's no rank of theirs for weekly usage to stand in for.
$rankPart = $null
$bannerLines = @()
if (-not $theme.Villain) {
    $rankInfo = Get-LevelFromWeekPct $week
    $rankLevel = $rankInfo.Level
    $rankAbbrev = Get-RankAbbrev $rankInfo.Continuous

    # Support Course cosmetic unlocks — reskins the progress bar's glyph pair
    # once your live level crosses a threshold. Purely cosmetic and computed
    # fresh every render like the rest of Rank: no state, no hook, just
    # "what does today's live level unlock". Highest unlocked tier wins;
    # default (▰▱) applies below level 5.
    $UnlockGlyphs = @(
        @{ Level = 40; Filled = '■'; Empty = '□' }   # Billboard Gauge
        @{ Level = 30; Filled = '●'; Empty = '○' }   # Orb Gauge
        @{ Level = 20; Filled = '◆'; Empty = '◇' }   # Diamond Gauge
        @{ Level = 15; Filled = '⬢'; Empty = '⬡' }   # Hex-Plate Gauge
        @{ Level = 10; Filled = '★'; Empty = '☆' }   # Starlight Gauge
        @{ Level = 5;  Filled = '▮'; Empty = '▯' }   # Twin-Blade Gauge
    )
    $barFilledGlyph = '▰'
    $barEmptyGlyph  = '▱'
    foreach ($tier in $UnlockGlyphs) {
        if ($rankLevel -ge $tier.Level) {
            $barFilledGlyph = $tier.Filled
            $barEmptyGlyph = $tier.Empty
            break
        }
    }
    $barSegments = 5
    $rankFraction = $rankInfo.Continuous - $rankLevel   # progress within the current level, 0-1
    $rankFilled = [math]::Min($barSegments, [math]::Floor($rankFraction * $barSegments))
    $rankBar = ($barFilledGlyph * $rankFilled) + ($barEmptyGlyph * ($barSegments - $rankFilled))

    $rankPart = "$C_QUIRK$rankAbbrev · Lv$rankLevel $rankBar$RESET"

    # Quirk Registry level-up banner — fires once, on the render right after
    # $rankLevel crosses a multiple-of-10 boundary since the last render.
    # Best-effort: an unreadable/unwritable file just means "no banner this
    # time", never an error, same promise as the rest of this script.
    $lastLevelFile = Join-Path $PSScriptRoot 'mha-rank-last-level.txt'
    try {
        $lastLevel = $null
        if (Test-Path $lastLevelFile) {
            $raw = (Get-Content -Raw $lastLevelFile).Trim()
            if ($raw -match '^\d+$') { $lastLevel = [int]$raw }
        }
        if ($null -ne $lastLevel -and $rankLevel -gt $lastLevel -and [math]::Floor($rankLevel / 10) -gt [math]::Floor($lastLevel / 10)) {
            $bannerLines = Get-LevelUpBanner -Icon $QUIRK_ICON -HeroName $HERO_NAME -Level $rankLevel -StageAbbrev $rankAbbrev -Color $C_QUIRK -Reset $RESET
        }
        Set-Content -Path $lastLevelFile -Value $rankLevel -Encoding utf8 -NoNewline
    } catch { }
}

# Cooldown (5h rate limit) — the only remaining optional segment. The 7d
# weekly figure used to ride along here too, but #rank above is now precise
# enough to speak for itself, so it's dropped rather than shown twice.
$cooldownPart = $null
if ($null -ne $five) {
    $cooldownPart = "$C_COOLDOWN⏱ 5h:$([math]::Round([double]$five))%$RESET"
}

$separator = "$DIM · $RESET"

# UA's motto, always shown last — theme-neutral (not tied to any character's
# accent color) since it's the school's line, not any one hero's. League of
# Villains themes get their own twist on it instead — they didn't graduate
# UA and don't answer to its motto.
if ($theme.Villain) {
    $mottoPart = "$BOLD$(Ansi256 196)Go beyond, Plus Chaos! 😈$RESET"
} else {
    $mottoPart = "$BOLD$(Ansi256 201)Go beyond, Plus Ultra! 💪$RESET"
}

# One line: Quirk, Agency, Rank, (if present) Cooldown, then the motto.
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add($quirkPart)
$parts.Add($agencyPart)
if ($rankPart) { $parts.Add($rankPart) }
if ($cooldownPart) { $parts.Add($cooldownPart) }
$parts.Add($mottoPart)
$line = $parts -join $separator

# Level-up banner (if any) renders on its own lines above the normal status
# line — see Get-LevelUpBanner and the crossing-detection above.
$outputLines = New-Object System.Collections.Generic.List[string]
foreach ($bl in $bannerLines) { $outputLines.Add($bl) }
$outputLines.Add($line)
$output = $outputLines -join "`n"

$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write($output)
$stdoutWriter.Flush()
