---
description: Switch the My Hero Academia statusline theme (all of Class 1-A, plus Aizawa-sensei and All Might)
argument-hint: [deku|bakugo|uraraka|todoroki|allmight|iida|momo|kirishima|kaminari|jiro|tokoyami|ashido|asui|shoji|sato|sero|aoyama|ojiro|hagakure|koda|mineta|aizawa]
allowed-tools: Bash, PowerShell, AskUserQuestion
---

Switch the mha-statusline theme for this user. All 22 themes, with a one-line
flavor description each (for when you need to present them):

**The core four + All Might**
- **deku** — Deku (Izuku Midoriya): One For All green, hero-red accents. Default.
- **bakugo** — Bakugo (Katsuki): explosion orange, olive accents.
- **uraraka** — Uraraka (Ochako): zero-gravity pink, sky-blue cooldown.
- **todoroki** — Todoroki (Shoto): half ice-blue, half fire-red.
- **allmight** — All Might: hero-suit blue and gold.

**Rest of Class 1-A**
- **iida** — Iida (Tenya): engine blue, recipro-burst red.
- **momo** — Yaoyorozu (Momo): Creation crimson, gold trim.
- **kirishima** — Kirishima (Eijiro): hardened red, manly orange.
- **kaminari** — Kaminari (Denki): electric yellow.
- **jiro** — Jiro (Kyoka): earphone-jack purple.
- **tokoyami** — Tokoyami (Fumikage): Dark Shadow red-black.
- **ashido** — Ashido (Mina): acid pink.
- **asui** — Asui (Tsuyu): frog green.
- **shoji** — Shoji (Mezo): Dupli-Arms gray-purple.
- **sato** — Sato (Rikido): sugar-rush brown-orange.
- **sero** — Sero (Hanta): tape gold.
- **aoyama** — Aoyama (Yuga): twinkling gold.
- **ojiro** — Ojiro (Mashirao): tail brown.
- **hagakure** — Hagakure (Toru): barely-there white.
- **koda** — Koda (Koji): quiet forest green.
- **mineta** — Mineta (Minoru): pop-off purple.

**Homeroom teacher**
- **aizawa** — Aizawa-sensei (Shota): tired gray, capture-scarf.

If `$ARGUMENTS` names one of these 22 keys (case-insensitive; also accept a
close match on the character's first or last name, e.g. "tsuyu" or "eraserhead"
→ `asui`/`aizawa`), just run it directly, no need to ask anything first:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/set-theme.ps1" -Theme <key>
```

If `$ARGUMENTS` is empty (or doesn't match a key), use the AskUserQuestion
tool: offer the four most-requested themes (deku, bakugo, uraraka, todoroki)
as the quick-pick options, and mention in the question text that any other
Class 1-A student, All Might, or Aizawa-sensei can be typed via "Other" —
that's faster than the script's own terminal menu since it's inline in the
chat, and the full 22-option list doesn't fit a single picker. If they type
a name via "Other", match it against the list above the same way as
`$ARGUMENTS` (key, first name, or last name). Then run the same
`set-theme.ps1 -Theme <choice>` command with their pick.

After it runs, confirm in one line and remind them to open a new Claude Code
session (or restart) to see it — the statusline is rendered by a separate
process that only re-reads the theme file on its next invocation.
