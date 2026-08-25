# mha-statusline — Project Ideas & Implementation Plans

Candidate follow-up projects for this repo, each scoped to become its own
branch (`feat/<name>`) off `master`. This doc is planning only — nothing here
is built yet. Each section has enough detail to start implementation without
re-deriving the design.

All ideas build on what already exists:
- `statusline.ps1` — the rendered line, theme catalogue, Rank/XP display
- `gain-xp.ps1` — `Stop` hook that grants XP once per finished turn
- `set-theme.ps1` / `commands/mha-theme.md` — theme switching (22 themes)
- `~/.claude/mha-statusline-state.json` — persisted Rank/XP state
- `~/.claude/mha-theme.txt` — persisted theme key

Reuse these where possible instead of inventing parallel state files.

---

## 1. `feat/aizawa-review` — Aizawa-sensei code reviewer subagent

**Pitch:** A Claude Code subagent with Aizawa Shota's personality — flat,
blunt, zero enthusiasm, "expels" bad code without ceremony — that stands in
for `/code-review` when you want a stricter, no-fluff pass.

**Why it fits:** Aizawa is UA's homeroom teacher whose canon introduction is
literally a fake-out expulsion test ("this is a test to determine who will be
expelled today"). A reviewer persona that's terse and unimpressed by default,
only softening when something is genuinely good, maps directly onto that.

**Mechanism:** Claude Code subagent definition (`.claude/agents/*.md`
frontmatter + system prompt), same shape as this project's other agent refs
(`claude-code-guide`, `Plan`, etc. in the system prompt's agent list).

**Files:**
- `agents/aizawa.md` (repo) — frontmatter (`name`, `description`, `tools`,
  `model`) + system prompt defining voice/scoring rubric
- `install.ps1` — copy it to `~/.claude/agents/aizawa.md` alongside the
  existing copy steps
- `README.md` — new "Aizawa review" section

**Plan:**
1. Write the persona prompt: terse sentences, no hedging, a pass/fail verdict
   up front, then a short list of what would get you expelled. Explicitly
   forbid praise-sandwiching — Aizawa doesn't do that.
2. Scope tools to read-only (`Read, Grep, Glob, Bash` for running
   tests/linters) — it reviews, it doesn't fix.
3. Decide invocation: a `/aizawa-review` slash command that spawns the
   subagent via the `Agent` tool with the current diff, mirroring how
   `/code-review` already works but pointed at this persona instead of the
   default reviewer.
4. Test on a deliberately mediocre diff and a genuinely clean one — verify
   the tone actually differs (should still be terse on the clean one, not
   suddenly chatty).
5. Wire into `install.ps1` / `uninstall.ps1` like the other assets.

**Effort:** S (mostly prompt-writing; no new runtime logic).

**Open questions:** Should it be a full subagent (isolated context) or a
lighter prompt template invoked inline? Subagent is cleaner but costs a
fresh context per call — fine for an occasional strict-pass tool.

---

## 2. `feat/villain-alerts` — Notification hook as "Villain Attack!"

**Pitch:** Hook Claude Code's `Notification` event (fires on permission
prompts, idle waits, etc.) to print/announce a themed alert instead of the
default, using whichever hero theme is active.

**Why it fits:** Villain attacks are MHA's actual "attention required" event
— heroes get called in. A themed alert for "Claude needs your input" is a
natural reskin.

**Mechanism:** `hooks.Notification` in `settings.json`, same wiring pattern
`install.ps1` already uses for the `Stop` hook (`gain-xp.ps1`).

**Files:**
- `villain-alert.ps1` (repo, new) — reads `mha-theme.txt` for flavor, prints
  a themed line; optionally shells out to `[console]::beep` or a toast
  notification
- `install.ps1` — wire into `hooks.Notification`, merging like the `Stop`
  hook block already does (don't clobber existing hooks)
- `uninstall.ps1` — matching removal

**Plan:**
1. Confirm the exact payload shape Claude Code passes to `Notification`
   hooks (message text, event type) — check current CLI docs/changelog
   since this varies by version.
2. Write `villain-alert.ps1`: parse stdin JSON, pick a per-theme "villain
   alert" line (reuse the `$Themes` catalogue's colors — either duplicate a
   trimmed copy or factor color/icon lookup into a tiny shared function both
   scripts source, to avoid drift between two hardcoded tables).
3. Decide on noise level: text-only by default; make sound/toast opt-in via
   an env var or a flag file, since notification hooks fire often and a
   sound on every one would get old fast.
4. Add to `install.ps1`/`uninstall.ps1` following the `Stop` hook precedent
   exactly (merge-safe, idempotent re-install).
5. Manual test: trigger a permission prompt, confirm the themed alert fires
   once, not per keystroke.

**Effort:** M (hook payload shape needs verifying; sharing the theme table
without duplicating it needs a small refactor).

**Risk:** Duplicating `$Themes` between `statusline.ps1` and this script is
exactly the kind of drift the repo has hit before (see the Kaminari/Ashido
name fixes). If this ships, extract the catalogue into a `themes.ps1` both
scripts dot-source, rather than copy-pasting the hashtable.

---

## 3. `feat/ua-output-style` — Output style with hero-briefing tone

**Pitch:** A custom Claude Code output style (`~/.claude/output-styles/`)
that nudges responses toward a light "mission briefing / mission complete"
framing — plans stated like a pre-patrol briefing, summaries like a
debrief — without going full cosplay or hurting task clarity.

**Why it fits:** Keeps the theme present in how Claude *talks*, not just the
statusline, but stays subtle enough not to get in the way of actual work.

**Mechanism:** Output style file (system-prompt-level tone instructions).
Exact file format/location should be pulled from current Claude Code docs
before writing — output styles are a newer surface and may have changed
shape since training.

**Files:**
- `output-styles/ua-hero.md` (repo, new)
- `install.ps1` — copy alongside the other install steps, **optional**
  (should not be force-enabled; output styles are more invasive than a
  statusline, so install.ps1 should ask, default no)

**Plan:**
1. Look up the current output-style file contract (likely via
   `claude-code-guide` agent or the docs) before writing anything — don't
   guess the schema.
2. Draft tone rules: short "briefing" framing at the start of multi-step
   plans, "mission complete" framing at the end of finished work, hero
   vocabulary used sparingly (once per response max) so it reads as flavor,
   not noise.
3. Explicitly rule out: catchphrases mid-explanation, anything that adds
   verbosity to technical answers, any change to code style/output format.
4. Make install opt-in (prompt in `install.ps1`, default declined) since this
   changes Claude's actual behavior everywhere, not just this repo's
   statusline — a much bigger ask on the user than a color scheme.
5. Dogfood it for a few real sessions before README-ing it as done; tone
   experiments are easy to get wrong and only obvious in use.

**Effort:** M (schema lookup + iteration on tone, which is inherently
subjective and needs real usage to validate).

**Risk:** Highest "annoying if wrong" ratio of all these ideas — bad tone
styling actively degrades every response, not just a cosmetic line. Ship
opt-in, get explicit user approval on the actual tone before making it the
default suggestion.

---

## 4. `feat/support-course-shop` — Spend XP on statusline cosmetics

**Pitch:** Extend the existing Rank/XP system: instead of XP only tracking
level, let it unlock small statusline cosmetic variants — alternate XP-bar
glyphs, a border/frame style, a badge for the Cooldown segment — themed as
"support items" from UA's Support Course (Mei Hatsume's department).

**Why it fits:** Directly reuses the existing leveling system instead of
building a new one; "support items" are established in-universe as
gear heroes unlock/requisition, not power-ups, so it stays lore-consistent
with a statusline being cosmetic.

**Mechanism:** Extends `mha-statusline-state.json` (already the source of
truth for level/XP) with an `unlocks` array; `statusline.ps1` reads it to
pick cosmetic variants.

**Files:**
- `gain-xp.ps1` — on level-up, roll/grant an unlock, append to state JSON
- `statusline.ps1` — read `unlocks`, apply the corresponding cosmetic
  (e.g. swap `▰▱` for an unlocked glyph pair, or add a small badge)
- `README.md` — document the unlock table (mirrors the existing Rank table)

**Plan:**
1. Design the unlock table: pick 4-6 cosmetic variants tied to specific
   levels (reuse the existing level thresholds — Y1/Y2/Y3/License/Sidekick/
   Agency Founder are already meaningful checkpoints, attach one unlock
   each rather than inventing a second progression axis).
2. Extend the state JSON schema additively (`unlocks: [...]`) — must stay
   backward compatible with existing state files that don't have the field
   (default to empty array, matches the existing `Test-Path`/try-catch
   fallback pattern already used for missing state).
3. `gain-xp.ps1`: on crossing a threshold, append the unlock key once
   (idempotent — check it's not already in the array before adding).
4. `statusline.ps1`: small lookup from unlock key → cosmetic swap; keep the
   default (no unlocks) rendering identical to today's output so existing
   users see zero change until they level up again.
5. Test the full arc: fresh state file → simulate XP up to each threshold →
   confirm each unlock applies exactly once and prior ones persist.

**Effort:** S-M (additive change to two already-understood files, small
state-schema migration).

**Open questions:** Should unlocks be per-theme (Deku's unlock cosmetics
differ from Bakugo's) or universal? Universal is simpler and avoids a 22x
content multiplication; recommend starting universal.

---

## 5. `feat/commit-hero-names` — Commit-type emoji via git hook

**Pitch:** A `prepare-commit-msg` git hook that prefixes conventional-commit
types with a themed emoji matching the active hero theme (`feat:` → 💥,
`fix:` → 🩹, `refactor:` → ✨, etc.), applied to *this repo's own commits*
(or any repo the user opts it into).

**Why it fits:** Lightweight, low-risk flavor that doesn't touch Claude Code
internals at all — pure git tooling, so it's the safest/fastest of the
batch to ship and the easiest to disable if it's annoying.

**Mechanism:** Standard git hook (`.git/hooks/prepare-commit-msg`), installed
per-repo (git hooks aren't global) via a small installer script.

**Files:**
- `hooks/prepare-commit-msg.ps1` (repo, new) — reads the theme file, maps
  commit-type prefix → emoji, rewrites the first line if it matches a known
  conventional-commit type and doesn't already start with an emoji
- `install-git-hook.ps1` (repo, new) — copies the hook into whatever repo
  it's run from (`.git/hooks/`), separate from the main `install.ps1` since
  this targets a *different* repo each time it's run, not `~/.claude/`

**Plan:**
1. Define the type→emoji map (reuse existing per-theme colors isn't
   applicable here since git commit messages are plain text — emoji only,
   no ANSI).
2. Write the hook script: git passes the commit-msg file path as `$args[0]`;
   read it, check first line against `^(feat|fix|refactor|docs|test|chore)(\(.+\))?:`,
   prepend emoji if matched and not already present, write back.
3. Make it idempotent — running `git commit --amend` shouldn't double-prefix.
4. `install-git-hook.ps1`: detect `.git/hooks/` in cwd, warn and abort if
   not a git repo, back up any existing `prepare-commit-msg` hook before
   overwriting (never silently clobber another tool's hook).
5. Test with `git commit -m "feat: thing"` and confirm the rewritten
   message; test amend doesn't double up; test a non-conventional message
   passes through untouched.

**Effort:** S (smallest of the batch, no Claude Code integration at all).

**Risk:** Lowest risk in the list — worst case it's a no-op emoji prefixer.
Main thing to get right is not clobbering a hook the user already has.

---

## 6. `feat/agency-sim` — Text-based hero agency sim

**Pitch:** The biggest lift here — turn the existing Rank/XP counter into a
lightweight sim: commits become "patrols," failed tests become "villain
encounters," PR merges become "missions complete." A `/patrol` command
narrates a short randomized event tied to what actually happened in the
session, with its own currency (Hero Points) separate from XP/level.

**Why it fits:** README already credits
[Claudemon](https://github.com/zamarrowski/claudemon) as inspiration and
explicitly says "no catching/battling, just climbing ranks" — this is the
natural next step *if* the user wants that scope, without pretending it's
not a bigger feature than everything else on this list.

**Mechanism:** New state file (`~/.claude/mha-agency-state.json`, separate
from the Rank state to avoid coupling an experimental feature to the stable
one), a new `Stop`-hook-adjacent script that inspects what the turn did
(git diff stats already available via `cost.total_lines_added/removed` in
the statusline payload; test pass/fail would need to shell out or parse
tool-call history), and a `/patrol` slash command for on-demand narration.

**Files:**
- `agency-sim.ps1` (repo, new) — event roller + state writer
- `commands/patrol.md` (repo, new) — slash command for narrated summary
- separate state file as above
- `README.md` — new section, clearly marked as a separate opt-in feature

**Plan (phased — do not build all at once):**
1. **Phase 1 (data only):** log events (patrol/villain/mission) to the new
   state file from the existing `Stop` hook's data, no narration yet — just
   prove the event classification is sane using real session data.
2. **Phase 2 (narration):** `/patrol` reads recent events, generates a short
   themed summary using canned templates per event type (not freeform LLM
   narration at first — keep it deterministic and testable).
3. **Phase 3 (decide statusline integration):** does Hero Points show
   anywhere in `statusline.ps1`, or stay a `/patrol`-only stat? Recommend
   keeping it out of the main line — this project's whole recent direction
   has been *removing* clutter from the line (Stamina/Cost/+/- all got cut
   for exactly this reason), so a second currency competing for the same
   space needs a strong reason to earn a spot there.
4. Get explicit sign-off on scope after Phase 1 before building 2-3 — this
   is speculative enough that the fun factor needs validating early.

**Effort:** L. This is a distinct feature, not an extension — treat it as
its own mini-project with its own review checkpoints, not a quick branch.

**Open question:** Is "villain encounter" (failed test/lint) something the
user actually wants surfaced, or does that read as nagging? Worth a quick
gut-check before Phase 2.

---

## 7. `feat/class-roster` — Multi-machine Class 1-A dashboard

**Pitch:** If the same person runs Claude Code across multiple machines/
repos with this installed, sync each install's Rank stats somewhere central
and render a "Class 1-A ranking board" (Sports-Festival-style leaderboard)
as a Claude Artifact.

**Why it fits:** Class 1-A's Sports Festival is a real in-universe ranked
event; framing multi-machine stats as a leaderboard is a clean metaphor.

**Mechanism:** This is the one idea that needs external state (each install
only knows its own `mha-statusline-state.json`) — needs either (a) manual
export/import, or (b) a real sync backend. Scope (b) down hard for v1.

**Files:**
- `export-stats.ps1` (repo, new) — dumps local state to a shareable JSON
- a published Artifact (not a repo file) that reads pasted/uploaded JSON and
  renders the board — **not** a live-syncing service unless the user
  explicitly wants to stand up real infrastructure for this

**Plan:**
1. **Scope check first:** confirm whether "multi-machine" actually applies
   to this user's setup before building anything — if there's only one
   machine, this idea doesn't apply and should be dropped, not built
   speculatively.
2. v1: `export-stats.ps1` prints/saves a small JSON blob (theme, level, XP,
   hero name). Manually combine 2+ exports, paste into an Artifact that
   renders a static leaderboard. No auto-sync, no server.
3. Only consider a live/shared version (Artifact `capabilities`, e.g. shared
   state) if v1 actually gets used — don't build sync infra speculatively.

**Effort:** S for v1 (static/manual), L if it grows into live sync — treat
those as two very different projects, not one branch.

**Risk:** Easiest idea on this list to over-engineer. Keep v1 embarrassingly
manual and only invest further if it proves useful.

---

## 8. `feat/quirk-registry` — ASCII art on level-up milestones

**Pitch:** On crossing a milestone level (every 5 or 10), print a small
ASCII-art portrait of the active theme's character to the terminal once, as
an "achievement unlocked" moment, then get out of the way.

**Why it fits:** Cheap, pure delight — no new systems, just a nice surprise
tied to the existing level-up moment.

**Mechanism:** Triggered from `gain-xp.ps1` (it already knows old level vs.
new level after granting XP) — print directly to stderr/stdout at that
point, once, not from `statusline.ps1` (which re-runs every prompt and
would spam the art every render).

**Files:**
- `ascii-art/*.txt` (repo, new) — one small (~8-12 line) art file per theme,
  22 total
- `gain-xp.ps1` — after computing new level, check if it crossed a milestone
  (`oldLevel / 5 != newLevel / 5` or similar), print the matching art

**Plan:**
1. Source or hand-draw compact ASCII art for all 22 characters — this is
   the actual bulk of the work. Check licensing/attribution norms for any
   art sourced externally rather than hand-drawn; simplest is small
   original monospace sketches (icon-level simplicity, not detailed
   portraits) to avoid any copyright question entirely.
2. `gain-xp.ps1`: add the milestone check right after the existing
   level/XP update, gated so it only fires once per crossing (not every
   turn while sitting at a milestone level).
3. Print via `Write-Host` directly from the hook (hooks can write to the
   transcript/console depending on Claude Code's hook-output handling —
   verify current behavior, since silently swallowed hook stdout would make
   this a no-op).
4. Keep art small — this should read as a nice ping, not take over the
   terminal.

**Effort:** M (mostly art production, not code — 22 pieces of small ASCII
art is real content work even if each one is simple).

**Risk:** Depends entirely on whether `Stop` hook output is actually visible
to the user in the current Claude Code version — confirm this before
committing to the approach; if hook output is swallowed, this needs a
different trigger point (e.g. read from `statusline.ps1` but only render
once via a "seen" flag in state, showing it inline in the statusline for
exactly one render).

---

## Suggested order

If picking one to start: **#5 (`commit-hero-names`)** is the fastest,
lowest-risk way to ship something new. **#1 (`aizawa-review`)** is the next
best value-for-effort. **#3 (`ua-output-style`)** and **#6 (`agency-sim`)**
need the most amount of upfront validation (docs lookup / scope discussion)
before writing code — don't start those without a scoping conversation
first.
