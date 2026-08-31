---
description: Report Agency Sim patrol stats (patrols/villain encounters/missions logged by agency-sim.ps1)
allowed-tools: Bash, PowerShell, Read
---

Report the Agency Sim log — this is a **factual readout of logged data**,
not freeform storytelling. Do not invent events, dates, or details that
aren't in the state file.

1. Read `~/.claude/mha-agency-state.json`. If it doesn't exist yet, say so
   plainly (e.g. "No patrol data yet — agency-sim.ps1 hasn't run, or
   `install.ps1` hasn't wired it into the Stop hook.") and stop there — do
   not fabricate a report from nothing.
2. Read `~/.claude/mha-theme.txt` for the active theme key (default `deku`
   if missing), and use that theme's hero name from the table in
   `commands/mha-theme.md` for light flavor in the header only — not
   throughout.
3. Report, using only what's actually in the state file:
   - Total counts: `<N> patrols · <N> villain encounters · <N> missions`
   - The most recent 5 entries from `recent`, each as `<type> · <cwd> ·
     <at>` (convert `at` from UTC ISO to something readable, but don't
     invent a timezone if you can't determine the user's local one — UTC
     is fine to state as UTC)
4. One line of closing color is fine (e.g. "steady week" if patrol count is
   high and villain/mission counts are low, or similar) — but keep it to
   one line, grounded in the actual numbers, not a story.

This command only reads state — it never modifies
`~/.claude/mha-agency-state.json`.
