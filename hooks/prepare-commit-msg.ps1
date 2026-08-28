# commit-hero-names — prefixes a conventional-commit first line with a
# themed emoji, e.g. "feat: thing" -> "💥 feat: thing".
#
# Invoked by the `prepare-commit-msg` shim (see hooks/prepare-commit-msg)
# with git's standard arguments:
#   prepare-commit-msg.ps1 <msg-file> [<commit-source>] [<sha1>]
# https://git-scm.com/docs/githooks#_prepare_commit_msg
param(
    [Parameter(Mandatory = $true)][string]$MsgFile,
    [string]$Source,
    [string]$Sha1
)
$ErrorActionPreference = 'SilentlyContinue'

# Merge/squash messages aren't conventional-commit subject lines — leave
# them alone entirely rather than risk mangling one.
if ($Source -eq 'merge' -or $Source -eq 'squash') { exit 0 }

if (-not (Test-Path $MsgFile)) { exit 0 }

# Conventional-commit type -> emoji. One fixed map, not per mha-statusline
# hero-theme — see docs/PROJECT-IDEAS.md #5 for why: this hook has to work
# in any repo, with or without mha-statusline's theme file present.
$typeEmoji = [ordered]@{
    'feat'     = '💥'   # new power unlocked
    'fix'      = '🩹'   # patched up
    'refactor' = '✨'   # cleaner form, same quirk
    'docs'     = '📚'
    'test'     = '🧪'   # Support Course lab work
    'style'    = '🎨'
    'perf'     = '⚡'
    'build'    = '🏗️'
    'ci'       = '🤖'   # 0-Pointer training robots
    'chore'    = '🧹'
    'revert'   = '⏪'
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$lines = [System.IO.File]::ReadAllLines($MsgFile, $utf8NoBom)
if ($lines.Count -eq 0) { exit 0 }

$firstLine = $lines[0]

# Matches "type(scope)?!?: subject". Already-prefixed lines (a re-run on
# amend, or the user typed their own emoji first) don't start with a bare
# a-z type anymore, so they naturally fail this match — that's what makes
# re-running this hook idempotent without any separate "already tagged"
# check.
if ($firstLine -notmatch '^(?<type>[a-z]+)(?<scope>\([^)]*\))?(?<bang>!)?:\s') { exit 0 }

$type = $Matches['type']
if (-not $typeEmoji.Contains($type)) { exit 0 }

$lines[0] = "$($typeEmoji[$type]) $firstLine"
[System.IO.File]::WriteAllLines($MsgFile, $lines, $utf8NoBom)
