# Claude Code "Stop" hook for the Agency Sim companion feature (Phase 1:
# event logging only -- see docs/PROJECT-IDEAS.md #6 for the full staged
# plan; phases 2/3 (freeform narration, statusline integration) are
# deliberately NOT built here, per that doc's own note to validate scope
# before going further than data logging + a plain report).
#
# Classifies each finished turn as one of:
#   mission  -- a Bash tool_use ran `git commit` or `git push` this turn
#   villain  -- a tool_result came back with is_error this turn (and no
#               mission signal took priority)
#   patrol   -- neither of the above; the default, everyday case
#
# This is NOT a guess at the transcript format -- verified against a real,
# live transcript file before writing this: `type: "assistant"` entries'
# message.content[] hold tool_use blocks (name/input.command for Bash),
# `type: "user"` entries' message.content[] hold the matching tool_result
# blocks (content/is_error). Only reads lines added since the last run (an
# offset per transcript_path in the state file) so this stays cheap even
# once a transcript grows to thousands of lines.
#
# Separate state file from gain-xp.ps1's (mha-agency-state.json vs
# mha-statusline-state.json) and its own lock -- deliberately not sharing
# either with the Rank/XP feature, so a bug here can't touch that state.
$ErrorActionPreference = 'SilentlyContinue'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8NoBom)
$raw = $stdinReader.ReadToEnd()
try { $hookInput = $raw | ConvertFrom-Json } catch { $hookInput = $null }
if (-not $hookInput -or -not $hookInput.transcript_path) { exit 0 }

$transcriptPath = $hookInput.transcript_path
$cwd = if ($hookInput.cwd) { $hookInput.cwd } else { (Get-Location).Path }
if (-not (Test-Path $transcriptPath)) { exit 0 }

$claudeDir = Split-Path -Parent $PSCommandPath
$stateFile = Join-Path $claudeDir 'mha-agency-state.json'
$lockFile  = Join-Path $claudeDir 'mha-agency-state.lock'

$acquired = $false
for ($i = 0; $i -lt 50; $i++) {
    try {
        $fs = [System.IO.File]::Open($lockFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
        $fs.Close()
        $acquired = $true
        break
    } catch {
        Start-Sleep -Milliseconds 50
    }
}
if (-not $acquired) { exit 0 }

try {
    $state = $null
    if (Test-Path $stateFile) {
        try { $state = Get-Content -Raw $stateFile | ConvertFrom-Json } catch { $state = $null }
    }
    if (-not $state) {
        $state = [PSCustomObject]@{
            counts            = [PSCustomObject]@{ patrol = 0; villain = 0; mission = 0 }
            recent            = @()
            transcriptOffsets = [PSCustomObject]@{}
        }
    }

    # Read only the lines this transcript has gained since we last looked.
    $offsetProp = $transcriptPath -replace '[^a-zA-Z0-9]', '_'   # PSCustomObject property names can't hold arbitrary paths safely
    $lastOffset = 0
    if ($state.transcriptOffsets.PSObject.Properties.Name -contains $offsetProp) {
        $lastOffset = [int]$state.transcriptOffsets.$offsetProp
    }

    $allLines = [System.IO.File]::ReadAllLines($transcriptPath)
    $newLines = if ($allLines.Count -gt $lastOffset) { $allLines[$lastOffset..($allLines.Count - 1)] } else { @() }

    $hasMission = $false
    $hasVillain = $false
    foreach ($ln in $newLines) {
        if (-not $ln) { continue }
        try { $entry = $ln | ConvertFrom-Json } catch { continue }
        $content = $entry.message.content
        if (-not $content) { continue }
        foreach ($c in @($content)) {
            if ($entry.type -eq 'assistant' -and $c.type -eq 'tool_use' -and $c.name -eq 'Bash') {
                $cmd = [string]$c.input.command
                if ($cmd -match 'git\s+commit' -or $cmd -match 'git\s+push') { $hasMission = $true }
            }
            if ($entry.type -eq 'user' -and $c.type -eq 'tool_result' -and $c.is_error) {
                $hasVillain = $true
            }
        }
    }

    $eventType = if ($hasMission) { 'mission' } elseif ($hasVillain) { 'villain' } else { 'patrol' }

    $countsProps = $state.counts.PSObject.Properties.Name
    if ($countsProps -contains $eventType) {
        $state.counts.$eventType = [int]$state.counts.$eventType + 1
    } else {
        $state.counts | Add-Member -MemberType NoteProperty -Name $eventType -Value 1
    }

    $newEvent = [PSCustomObject]@{
        type = $eventType
        at   = (Get-Date).ToUniversalTime().ToString('o')
        cwd  = $cwd
    }
    $recent = @(@($state.recent) + $newEvent)
    if ($recent.Count -gt 20) { $recent = $recent[-20..-1] }
    $state.recent = $recent

    if ($state.transcriptOffsets.PSObject.Properties.Name -contains $offsetProp) {
        $state.transcriptOffsets.$offsetProp = $allLines.Count
    } else {
        $state.transcriptOffsets | Add-Member -MemberType NoteProperty -Name $offsetProp -Value $allLines.Count
    }
    # Cap tracked transcripts so this doesn't grow forever across many
    # sessions -- keep only the most recently-touched handful.
    $offsetNames = @($state.transcriptOffsets.PSObject.Properties.Name)
    if ($offsetNames.Count -gt 50) {
        $toDrop = $offsetNames | Select-Object -First ($offsetNames.Count - 50)
        foreach ($d in $toDrop) { $state.transcriptOffsets.PSObject.Properties.Remove($d) }
    }

    $tmpFile = "$stateFile.tmp"
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $tmpFile -Encoding utf8 -NoNewline
    Move-Item -Path $tmpFile -Destination $stateFile -Force
} finally {
    Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
}
