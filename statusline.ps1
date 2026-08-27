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
        Label     = 'En'
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
        Label     = 'All For One'
        QuirkIcon = '👑'
        Quirk     = Ansi256 54    # All For One — imperial purple-black
        Agency    = Ansi 91
        Cooldown  = Ansi256 236
        Hero      = 'All For One'
        Villain   = $true
    }
    'muscular' = @{
        Label     = 'Muscular'
        QuirkIcon = '💪'
        Quirk     = Ansi256 204   # Muscle Augmentation — veiny pink-red
        Agency    = Ansi 91
        Cooldown  = Ansi256 88
        Hero      = 'Muscular'
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
    'nine' = @{
        Label     = 'Nine'
        QuirkIcon = '⛈️'
        Quirk     = Ansi256 103   # Weather Manipulation — storm gray-purple
        Agency    = Ansi 91
        Cooldown  = Ansi256 60
        Hero      = 'Nine'
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
    'manual', 'midnight', 'nezu', 'nighteye', 'powerloader', 'presentmic',
    'recoverygirl', 'selkie', 'snipe', 'thirteen', 'uwabami', 'vladking',
    # Pro heroes
    'bestjeanist', 'edgeshot', 'endeavor', 'fatgum', 'grantorino',
    'gunhead', 'hawks', 'kamuiwoods', 'mirko', 'mtlady', 'rocklock',
    'ryukyu', 'starandstripe',
    # League of Villains, Meta Liberation Army, and other villains who've
    # carried their own arc
    'allforone', 'dabi', 'garaki', 'gentle', 'geten', 'labrava', 'ladynagant',
    'moonfish', 'mrcompress', 'muscular', 'mustard', 'nine', 'overhaul',
    'rappa', 'redestro', 'shigaraki', 'skeptic', 'spinner', 'stain', 'toga',
    'twice'
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
$parts.Add($rankPart)
if ($cooldownPart) { $parts.Add($cooldownPart) }
$parts.Add($mottoPart)
$line = $parts -join $separator

$stdoutWriter = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), $utf8NoBom)
$stdoutWriter.Write($line)
$stdoutWriter.Flush()
