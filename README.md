# mha-statusline

A [Claude Code](https://claude.com/claude-code) statusline themed after **My Hero
Academia** — pure PowerShell, zero dependencies. No Node.js, no npm, no jq, no
admin rights. Works on any locked-down Windows machine where PowerShell is the
only thing you're guaranteed to have.

```
💥 Sonnet 5  ⚡  🏫 my-project ⚡main  ⚡  🔋 Stamina:85% PLUS ULTRA!  ⚡  ⏱ 5h:18% 7d:63%  ⚡  🪙 $1.23  ⚡  +87 -12
```

## What it shows

| Segment | Meaning | Source |
|---|---|---|
| 💥 Quirk | Model name | `model.display_name` |
| 🏫 Agency | Current folder name + git branch (⚡ red) | `workspace.current_dir` / `git branch --show-current` |
| 🔋 Stamina | Context window remaining % — green ≥50%, gold 20-50%, red <20%. Shows **PLUS ULTRA!** at ≥80% | `context_window.remaining_percentage` |
| ⏱ Cooldown | Rate limit usage (5h / 7d window) | `rate_limits.five_hour` / `.seven_day` |
| 🪙 Cost | Session cost in USD | `cost.total_cost_usd` |
| +/- | Lines added / removed this session | `cost.total_lines_added` / `.total_lines_removed` |

Every field is optional — if Claude Code's statusline payload doesn't include it
(older CLI version, different plan), that segment is just skipped. The script
never throws: worst case it prints just the model name.

## Install

Clone or download this repo, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
```

This copies `statusline.ps1` to `~/.claude/statusline.ps1` and points
`~/.claude/settings.json`'s `statusLine` at it. Restart Claude Code afterwards.

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

Removes the `statusLine` entry from `settings.json`. `statusline.ps1` itself is
left on disk — delete it manually if you want it fully gone.

## Requirements

- Windows PowerShell 5.1+ (built into every Windows install) or PowerShell 7+.
- `git` on PATH, only for the branch name — everything else still works without it.
- A terminal that renders ANSI/VT100 escape codes (Windows Terminal, VS Code's
  integrated terminal, modern `conhost` — all of what Claude Code normally runs in).

## Customizing

All colors, icons and labels live at the top of `statusline.ps1` as plain
variables (`$C_QUIRK`, `$C_BRANCH`, etc.) and inline strings — edit and re-run
`install.ps1` to pick them up.

## Bonus: commit-hero-names git hook

A separate, optional `prepare-commit-msg` git hook that prefixes
conventional-commit messages with a themed emoji:

```
feat: add cool thing        ->  💥 feat: add cool thing
fix: broken thing           ->  🩹 fix: broken thing
refactor(api)!: rework      ->  ✨ refactor(api)!: rework
wip: still working          ->  wip: still working   (unknown type, untouched)
```

| Type | Emoji | | Type | Emoji |
|---|---|---|---|---|
| `feat` | 💥 | | `perf` | ⚡ |
| `fix` | 🩹 | | `build` | 🏗️ |
| `refactor` | ✨ | | `ci` | 🤖 |
| `docs` | 📚 | | `chore` | 🧹 |
| `test` | 🧪 | | `revert` | ⏪ |
| `style` | 🎨 | | | |

This is independent of the statusline install above and targets **whatever
repo you run it from** — git hooks aren't global, so each repo you want this
in needs its own install:

```powershell
cd C:\path\to\some-other-repo
powershell -NoProfile -ExecutionPolicy Bypass -File C:\path\to\mha-statusline\install-git-hook.ps1
```

It only touches the first line of `feat:`/`fix:`/etc.-style messages that
don't already start with an emoji — merge and squash commits, and messages
that don't match a known conventional-commit type, are left untouched.
Amending an already-prefixed commit doesn't double up the emoji. If the repo
already has a different `prepare-commit-msg` hook, it's backed up (never
clobbered) before this one is installed.

Remove it the same way:

```powershell
cd C:\path\to\some-other-repo
powershell -NoProfile -ExecutionPolicy Bypass -File C:\path\to\mha-statusline\uninstall-git-hook.ps1
```

which also restores the backed-up hook, if there was one.
