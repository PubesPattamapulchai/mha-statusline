# Switches the My Hero Academia statusline theme without reinstalling.
# Writes the chosen theme key to ~/.claude/mha-theme.txt, which statusline.ps1
# reads on every invocation.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File set-theme.ps1            # interactive menu
#   powershell -NoProfile -ExecutionPolicy Bypass -File set-theme.ps1 -Theme bakugo
param(
    [ValidateSet(
        'auto',
        'deku', 'uraraka', 'bakugo', 'todoroki', 'allmight',
        'iida', 'momo', 'kirishima', 'kaminari', 'jiro', 'tokoyami', 'ashido',
        'asui', 'shoji', 'sato', 'sero', 'aoyama', 'ojiro', 'hagakure', 'koda',
        'mineta', 'aizawa', 'shinzo',
        'monoma', 'kendo', 'tetsutetsu', 'tokage', 'shiozaki', 'kuroiro',
        'kamakiri', 'komori', 'awase', 'bondo', 'fukidashi', 'honenuki',
        'kaibara', 'kodai', 'rin', 'shishida', 'shoda', 'tsuburaba',
        'tsunotori', 'yanagi',
        'mirio', 'tamaki', 'nejire',
        'yoichi', 'kudo', 'brucelee', 'shinomori', 'banjo', 'en', 'nana',
        'presentmic', 'midnight', 'vladking', 'cementoss', 'powerloader',
        'nezu', 'recoverygirl', 'thirteen', 'ectoplasm', 'snipe',
        'hounddog', 'nighteye', 'selkie', 'manual', 'mandalay', 'pixiebob',
        'ragdoll', 'tiger', 'uwabami', 'burnin',
        'endeavor', 'hawks', 'mirko', 'bestjeanist', 'edgeshot',
        'grantorino', 'mtlady', 'kamuiwoods', 'fatgum', 'ryukyu',
        'gunhead', 'rocklock', 'starandstripe',
        'shigaraki', 'kurogiri', 'dabi', 'toga', 'twice', 'mrcompress', 'spinner',
        'overhaul', 'stain', 'allforone', 'muscular', 'magne',
        'geten', 'moonfish', 'mustard', 'rappa', 'redestro', 'skeptic',
        'gentle', 'labrava', 'ladynagant', 'garaki'
    )]
    [string]$Theme
)
$ErrorActionPreference = 'Stop'

$themes = [ordered]@{
    'auto'      = 'Auto-rotate — cycles through all 108 themes, a new one every 5 minutes [default]'
    'deku'      = 'Deku (Midoriya Izuku) — One For All green, hero-red accents'
    'uraraka'   = 'Uraraka (Ochako) — zero-gravity pink, sky-blue cooldown'
    'bakugo'    = 'Bakugo (Katsuki) — explosion orange, olive accents'
    'todoroki'  = 'Todoroki (Shoto) — half ice-blue, half fire-red'
    'allmight'  = 'All Might (Yagi Toshinori) — hero-suit blue and gold'
    'iida'      = 'Iida (Tenya) — Engine blue, recipro-burst red'
    'momo'      = 'Yaoyorozu (Momo) — Creation crimson, gold trim'
    'kirishima' = 'Kirishima (Eijiro) — hardened red, manly orange'
    'kaminari'  = 'Kaminari (Denki) — electric yellow'
    'jiro'      = 'Jiro (Kyoka) — earphone-jack purple'
    'tokoyami'  = 'Tokoyami (Fumikage) — Dark Shadow red-black'
    'ashido'    = 'Ashido (Mina) — acid pink'
    'asui'      = 'Asui (Tsuyu) — frog green'
    'shoji'     = 'Shoji (Mezo) — Dupli-Arms gray-purple'
    'sato'      = 'Sato (Rikido) — sugar-rush brown-orange'
    'sero'      = 'Sero (Hanta) — tape gold'
    'aoyama'    = 'Aoyama (Yuga) — twinkling gold'
    'ojiro'     = 'Ojiro (Mashirao) — tail brown'
    'hagakure'  = 'Hagakure (Toru) — barely-there white'
    'koda'      = 'Koda (Koji) — quiet forest green'
    'mineta'    = 'Mineta (Minoru) — pop-off purple'
    'aizawa'    = 'Aizawa-sensei (Shota) — homeroom teacher, tired gray'
    'shinzo'    = 'Shinzo (Hitoshi) — Brainwash violet, capture-scarf indigo'
    'monoma'    = 'Monoma (Neito), Class 1-B — Copy mirror-cyan'
    'kendo'     = 'Kendo (Itsuka), Class 1-B — Big Fist tan'
    'tetsutetsu'= 'Tetsutetsu Tetsutetsu, Class 1-B — Steel chrome-gray'
    'tokage'    = 'Tokage (Setsuna), Class 1-B — Lizard Tail Splitter green'
    'shiozaki'  = 'Shiozaki (Ibara), Class 1-B — Vines deep green'
    'kuroiro'   = 'Kuroiro (Shihai), Class 1-B — Black near-black'
    'kamakiri'  = 'Kamakiri (Togaru), Class 1-B — Razor Sharp mantis green'
    'komori'    = 'Komori (Kinoko), Class 1-B — Mushroom pink'
    'awase'     = 'Awase (Yosetsu), Class 1-B — Weld spark orange'
    'bondo'     = 'Bondo (Kojiro), Class 1-B — Cemedine glue tan'
    'fukidashi' = 'Fukidashi (Manga), Class 1-B — Comic speech-bubble yellow'
    'honenuki'  = 'Honenuki (Juzo), Class 1-B — Softening mud brown'
    'kaibara'   = 'Kaibara (Sen), Class 1-B — Gyrate drill orange'
    'kodai'     = 'Kodai (Yui), Class 1-B — Size soft blue'
    'rin'       = 'Rin (Hiryu), Class 1-B — Scales dragon blue'
    'shishida'  = 'Shishida (Jurota), Class 1-B — Beast feral brown'
    'shoda'     = 'Shoda (Nirengeki), Class 1-B — Twin Impact blast orange-red'
    'tsuburaba' = 'Tsuburaba (Kosei), Class 1-B — Solid Air pale blue'
    'tsunotori' = 'Tsunotori (Pony), Class 1-B — Horn Cannon pastel pink'
    'yanagi'    = 'Yanagi (Reiko), Class 1-B — Poltergeist psychic purple'
    'mirio'     = 'Togata (Mirio) "Lemillion" — Permeation gold, one of the Big 3'
    'tamaki'    = 'Amajiki (Tamaki) "Suneater" — Manifest indigo, one of the Big 3'
    'nejire'    = 'Hado (Nejire) "Nejire-chan" — Wave Motion blue, one of the Big 3'
    'yoichi'    = 'Shigaraki (Yoichi) — Quirk Bestowal, 1st OFA user, soft gold'
    'kudo'      = 'Kudo (Toshitsugu) — Gearshift, 2nd OFA user, mechanical blue-gray'
    'brucelee'  = 'Bruce Lee — Fa Jin, 3rd OFA user, explosive orange'
    'shinomori' = 'Shinomori (Hikage) — Danger Sense, 4th OFA user, stealth purple'
    'banjo'     = 'Banjo (Daigoro) — Blackwhip, 5th OFA user, black-purple'
    'en'        = 'En — Smokescreen, 6th OFA user, smoke purple'
    'nana'      = 'Shimura (Nana) — Float, 7th OFA user, All Might''s mentor, warm brown'
    'presentmic'  = 'Present Mic (Yamada Hizashi) — Voice radio-yellow'
    'midnight'    = 'Midnight (Kayama Nemuri) — Somnambulist purple'
    'vladking'    = 'Vlad King (Kan Sekijiro) — Blood Control dark red'
    'cementoss'   = 'Cementoss (Ishiyama Ken) — Cement concrete-gray'
    'powerloader' = 'Power Loader (Maijima Higari) — Metal Bulkup mining-orange'
    'nezu'        = 'Nezu — High Specs cream'
    'recoverygirl'= 'Recovery Girl (Shuzenji Chiyo) — Heal soft pink'
    'thirteen'    = 'Thirteen (Kurose Anan) — Black Hole void-black'
    'ectoplasm'   = 'Ectoplasm — Clones spectral teal'
    'snipe'       = 'Snipe — Homing cowboy brown'
    'hounddog'    = 'Hound Dog (Inui Ryo) — Dog canine tan'
    'nighteye'    = 'Sir Nighteye (Sasaki Mirai) — Foresight dark green'
    'selkie'      = 'Selkie — Spotted Seal gray-blue'
    'manual'      = 'Manual (Mizushima Masaki) — Water clear blue'
    'mandalay'    = 'Mandalay (Sosaki Shino) — Telepath leopard-print orange-brown, Wild Wild Pussycats'
    'pixiebob'    = 'Pixie-Bob (Tsuchikawa Ryuko) — Earth Flow earthen tan, Wild Wild Pussycats'
    'ragdoll'     = 'Ragdoll (Shiretoko Tomoko) — Search cheerful pink, Wild Wild Pussycats'
    'tiger'       = 'Tiger (Chatora Yawara) — Pliabody tiger-stripe burnt orange, Wild Wild Pussycats'
    'uwabami'     = 'Uwabami — Serpentress kimono purple-gold'
    'burnin'      = 'Burnin (Kamiji Moe) — Burning Hair orange-red'
    'endeavor'    = 'Endeavor (Todoroki Enji) — Hellflame blazing red'
    'hawks'       = 'Hawks (Takami Keigo) — Fierce Wings red-gold'
    'mirko'       = 'Mirko (Usagiyama Rumi) — Rabbit white'
    'bestjeanist' = 'Best Jeanist (Hakamada Tsunagu) — Fiber Master denim blue'
    'edgeshot'    = 'Edgeshot (Kamihara Shinya) — Ninja dark navy'
    'grantorino'  = 'Gran Torino (Torino Sorahiko) — Jet blue-gray'
    'mtlady'      = 'Mt. Lady (Takeyama Yu) — Gigantification yellow'
    'kamuiwoods'  = 'Kamui Woods (Nishiya Shinji) — Arbor bark brown'
    'fatgum'      = 'Fat Gum (Toyomitsu Taishiro) — Fat hero-jacket yellow'
    'ryukyu'      = 'Ryukyu (Tatsuma Ryuko) — Dragon western-dragon blue'
    'gunhead'     = 'Gunhead — gun-arm martial-arts tan'
    'rocklock'    = 'Rock Lock (Takagi Ken) — Lock Down gunmetal gray'
    'starandstripe' = 'Star and Stripe (Bate Cathleen) — New Order stars-and-stripes red/blue'
    'shigaraki'   = 'Shigaraki (Shimura Tomura) — Decay ashen blue-gray, League of Villains'
    'kurogiri'    = 'Kurogiri (Shirakumo Oboro) — Warp Gate misty violet-black, League of Villains'
    'dabi'        = 'Dabi (Todoroki Touya) — Cremation cold blue flame, League of Villains'
    'toga'        = 'Toga (Himiko) — Transform blood pink, League of Villains'
    'twice'       = 'Twice (Bubaigawara Jin) — Double bandage cyan, League of Villains'
    'mrcompress'  = 'Mr. Compress (Sako Atsuhiro) — Compress magician red, League of Villains'
    'spinner'     = 'Spinner (Iguchi Shuichi) — Gecko scaly red, League of Villains'
    'overhaul'    = 'Overhaul (Chisaki Kai) — Overhaul plague-mask gold, League of Villains'
    'stain'       = 'Stain (Akaguro Chizome) — Bloodcurdle bandage red, League of Villains'
    'allforone'   = 'All For One (Shigaraki Zen) — imperial purple-black, League of Villains'
    'muscular'    = 'Muscular (Imasuji Goto) — Muscle Augmentation veiny pink-red, League of Villains'
    'magne'       = 'Magne (Hikiishi Kenji) — Magnetism dark magenta-purple, League of Villains'
    'geten'       = 'Geten — Ice Manipulation pale ice-blue, League of Villains'
    'moonfish'    = 'Moonfish — Blade-Tooth cold steel-blue, Vanguard Action Squad'
    'mustard'     = 'Mustard — Gas toxic mustard yellow, Vanguard Action Squad'
    'rappa'       = 'Rappa (Kendo Rappa) — Kyoken Eight Bullets red'
    'redestro'    = 'Re-Destro (Yotsubashi Rikiya) — Stress MLA maroon, Meta Liberation Army'
    'skeptic'     = 'Skeptic (Chikazoku Tomoyasu) — Anthropomorph screen-glow cyan, Meta Liberation Army'
    'gentle'      = 'Gentle Criminal (Tobita Danjuro) — Larceny gentleman teal'
    'labrava'     = 'La Brava (Aiba Manami) — Love devoted pink'
    'ladynagant'  = 'Lady Nagant (Tsutsumi Kaina) — Rifle two-tone pink/dark-green'
    'garaki'      = 'Dr. Garaki (Ujiko Daruma) — Life Force sickly lab green'
}

if (-not $Theme) {
    Write-Host ""
    Write-Host "Choose a My Hero Academia statusline theme:" -ForegroundColor Cyan
    $keys = @($themes.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host ("  [{0}] {1} — {2}" -f ($i + 1), $keys[$i], $themes[$keys[$i]])
    }
    Write-Host ""
    $choice = Read-Host "Enter a number (1-$($keys.Count)), or a theme name [default: auto]"
    if (-not $choice) {
        $Theme = 'auto'
    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $keys.Count) {
        $Theme = $keys[[int]$choice - 1]
    } elseif ($themes.Contains($choice.Trim().ToLowerInvariant())) {
        $Theme = $choice.Trim().ToLowerInvariant()
    } else {
        Write-Host "Didn't recognize '$choice' — defaulting to auto." -ForegroundColor Yellow
        $Theme = 'auto'
    }
}

$claudeDir = Join-Path $HOME '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$themeFile = Join-Path $claudeDir 'mha-theme.txt'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($themeFile, $Theme, $utf8NoBom)

Write-Host "Theme set to '$Theme' ($($themes[$Theme]))." -ForegroundColor Green
Write-Host "Restart Claude Code (or open a new session) to see it." -ForegroundColor Yellow
