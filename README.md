# mha-statusline

A [Claude Code](https://claude.com/claude-code) statusline themed after **My Hero
Academia** — pure PowerShell, zero dependencies. No Node.js, no npm, no jq, no
admin rights. Works on any locked-down Windows machine where PowerShell is the
only thing you're guaranteed to have.

One line, kept minimal:

<p align="center"><img src="assets/demo.svg" alt="mha-statusline sample output, Deku theme: fist Sonnet 5 PLUS ULTRA, dot, my-project, dot, Y2 dot Lv7 XP bar 84 of 140, dot, stopwatch 5h 18% 7d 63%" width="640"></p>

## What it shows

| Segment | Meaning | Source |
|---|---|---|
| 💥 Quirk | Model name + the character's catchphrase (icon/phrase vary by [theme](#themes) — ✊ PLUS ULTRA! for Deku, shown above) | `model.display_name` |
| Agency | Current folder name | `workspace.current_dir` |
| Rank | Your hero career — see [Rank](#rank-hero-career-progression) below | `~/.claude/mha-statusline-state.json` |
| ⏱ Cooldown | Rate limit usage (5h / 7d window) | `rate_limits.five_hour` / `.seven_day` |

The git branch was dropped from the line entirely (not just hidden) to keep
things minimal — see [Customizing](#customizing) if you want it back.

Every field is optional — if Claude Code's statusline payload doesn't include it
(older CLI version, different plan), that segment is just skipped. The script
never throws: worst case it prints just the model name. Context-remaining %,
session cost, and lines-added/removed are intentionally left off the line to
keep it minimal — they're still in `settings.json`'s statusline payload if you
want to add a field back in [Customizing](#customizing).

## Rank: hero career progression

A small companion feature inspired by [Claudemon](https://github.com/zamarrowski/claudemon):
your own hero career levels up as you use Claude Code, shown as
`<stage> · Lv<N>  <XP bar>  xp/next`. Unlike Claudemon there's no
catching/battling — it's just you, climbing the ranks:

| Level | Shown as |
|---|---|
| 1-4 | `Y1` |
| 5-9 | `Y2` |
| 10-14 | `Y3` |
| 15-19 | `License` |
| 20-29 | `Sidekick` |
| 30-39 | `Agency Founder` |
| 40+ | `#300`…`#1` — the JP Hero Billboard Chart, a numeric rank that counts down as you level, reaching **#1** (Symbol of Peace) around level 99 |

XP is granted by a `Stop` hook (`gain-xp.ps1`) that fires once per finished
Claude Code turn and adds a small random amount to
`~/.claude/mha-statusline-state.json`. It's lock-protected so running several
agents/sessions in parallel doesn't lose XP to a race. `install.ps1` wires the
hook into `settings.json` automatically; if you run several Claude Code
installs that share the same `~/.claude`, XP accrues across all of them —
it's one shared hero career, not per-project.

## Themes

Five character themes, each with its own Quirk icon, color palette, and catchphrase:

<p align="center"><img src="assets/themes.svg" alt="Quirk icon and color per theme: fist green Deku, planet pink Uraraka, explosion orange Bakugo, snowflake blue Todoroki, flexed-bicep blue All Might" width="420"></p>

| Theme key | Character | Colors | Catchphrase |
|---|---|---|---|
| `deku` *(default)* | Deku (Izuku Midoriya) | One For All green, hero-red accents | PLUS ULTRA! |
| `uraraka` | Uraraka (Ochako) | Zero-gravity pink, sky-blue cooldown | ZERO GRAVITY! |
| `bakugo` | Bakugo (Katsuki) | Explosion orange, olive accents | I AM NUMBER ONE! |
| `todoroki` | Todoroki (Shoto) | Half ice-blue, half fire-red | FLASHFIRE FIST! |
| `allmight` | All Might | Hero-suit blue and gold | I AM HERE! |

`install.ps1` asks you to pick one on first install. To switch later, the
easiest way is right from the Claude Code chat:

```
/mha-theme
```

Answer the picker it shows, or skip straight to one: `/mha-theme bakugo`.

Or from a terminal, without opening Claude Code:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\set-theme.ps1"
```

Pass `-Theme` to skip its menu too: `... set-theme.ps1 -Theme bakugo`.

Either way this writes the theme key to `~/.claude/mha-theme.txt`, which
`statusline.ps1` reads on every invocation — no reinstall or `settings.json`
change needed (just a new Claude Code session, since the statusline is a
separate process that only re-reads the file on its next run). For a one-off
override (e.g. testing a theme in a single shell) set
`$env:MHA_STATUSLINE_THEME` before launching Claude Code; it takes priority
over the saved file.

## Install

Clone or download this repo, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

This copies `statusline.ps1`, `set-theme.ps1`, and `gain-xp.ps1` to `~/.claude/`,
plus the `/mha-theme` command to `~/.claude/commands/`. It points
`~/.claude/settings.json`'s `statusLine` at the first, wires `gain-xp.ps1`
into a `Stop` hook (merged with any hooks you already have — nothing is
clobbered), and asks you to pick a [theme](#themes) on first install. Restart
Claude Code afterwards.

`-ExecutionPolicy Bypass` only affects that one process — it does not change any
system-wide policy and does not require administrator rights, so it works even on
machines where you can't install software or change execution policy globally.

### Manual install

If you'd rather do it by hand:

1. Copy `statusline.ps1` to `%USERPROFILE%\.claude\statusline.ps1`.
2. In `%USERPROFILE%\.claude\settings.json`, set:
   ```json
   "statusLine": {
     "type": "command",
     "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<you>\\.claude\\statusline.ps1\""
   }
   ```
3. Restart Claude Code.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
```

Removes the `statusLine` entry and the `gain-xp.ps1` `Stop` hook from
`settings.json` (any other hooks you have are left untouched). The scripts
themselves and any saved theme/rank state are left on disk — delete them
manually from `~/.claude/` if you want it fully gone.

## Requirements

- Windows PowerShell 5.1+ (built into every Windows install) or PowerShell 7+.
- `git` on PATH, only for the branch name — everything else still works without it.
- A terminal that renders ANSI/VT100 escape codes (Windows Terminal, VS Code's
  integrated terminal, modern `conhost` — all of what Claude Code normally runs in).

## Customizing

All colors, icons and labels live at the top of `statusline.ps1` as plain
variables (`$C_QUIRK`, `$C_BRANCH`, etc.) and inline strings — edit and re-run
`install.ps1` to pick them up.
