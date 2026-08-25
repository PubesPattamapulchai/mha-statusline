---
description: Run a strict, no-fluff review of the current changes as Aizawa-sensei — terse verdict, no praise-sandwiching
argument-hint: [optional focus, e.g. "just the auth changes"]
allowed-tools: Agent, Bash
---

Run a review of the current working changes using the `aizawa` subagent
(see `agents/aizawa.md`) instead of the default reviewer persona.

1. Get the diff to review: `git diff` (unstaged) and `git diff --cached`
   (staged) against the current branch. If both are empty, diff against the
   branch's merge-base with the default branch instead (`git merge-base
   HEAD origin/master` or `origin/main`, whichever exists) so there's still
   something to review on a clean working tree.
2. If `$ARGUMENTS` narrows the scope (e.g. "just the auth changes"), pass
   that framing along so the subagent knows what to focus on — don't drop it
   silently.
3. Spawn the `aizawa` agent (via the Agent tool, `subagent_type: aizawa`)
   with the diff and any scope note. Let it do its own reading of the
   affected files rather than just handing it a raw diff with no context —
   point it at the repo so it can `Read`/`Grep` around the change.
4. Relay the subagent's verdict and issue list back verbatim — don't
   soften, don't add your own summary on top of it. That would undercut the
   whole point of asking for this persona instead of the default one.
