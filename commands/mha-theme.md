---
description: Switch the My Hero Academia statusline theme (Deku, Uraraka, Bakugo, Todoroki, All Might)
argument-hint: [deku|uraraka|bakugo|todoroki|allmight]
allowed-tools: Bash, PowerShell, AskUserQuestion
---

Switch the mha-statusline theme for this user. The five themes, with a
one-line flavor description each (for when you need to present them):

- **deku** — Deku (Izuku Midoriya): One For All green, hero-red accents. Default.
- **uraraka** — Uraraka (Ochako): zero-gravity pink, sky-blue cooldown.
- **bakugo** — Bakugo (Katsuki): explosion orange, olive accents.
- **todoroki** — Todoroki (Shoto): half ice-blue, half fire-red.
- **allmight** — All Might: hero-suit blue and gold.

If `$ARGUMENTS` names one of these five keys (case-insensitive), just run it
directly, no need to ask anything first:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/set-theme.ps1" -Theme <key>
```

If `$ARGUMENTS` is empty (or doesn't match a key), use the AskUserQuestion
tool to let the user pick one of the five from the list above — that's faster
than the script's own terminal menu since it's inline in the chat. Then run
the same `set-theme.ps1 -Theme <choice>` command with their pick.

After it runs, confirm in one line and remind them to open a new Claude Code
session (or restart) to see it — the statusline is rendered by a separate
process that only re-reads the theme file on its next invocation.
