# Installs the My Hero Academia statusline.
# Pure PowerShell — no node, no npm, no jq, no admin rights required.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1                  # Claude Code (default)
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Target Shell    # any terminal: Codex CLI, local LLM CLIs, plain shell
param(
    # ClaudeCode wires ~/.claude/settings.json's statusLine, exactly as before.
    # Shell instead hooks your PowerShell prompt directly (via $PROFILE), so
    # the line shows up in any terminal session — Codex CLI (whose own status
    # line only supports a fixed built-in item list, not custom commands: see
    # https://github.com/openai/codex/issues/20244), an `ollama run` session
    # or other local-LLM CLI, or a plain shell — regardless of which tool (if
    # any) is running there, since none of them expose a Claude-Code-style
    # statusLine hook of their own.
    [ValidateSet('ClaudeCode', 'Shell')]
    [string]$Target = 'ClaudeCode'
)
$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $HOME '.claude'
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

# statusline.ps1 and set-theme.ps1 always live in ~/.claude/, regardless of
# target, so /mha-theme, set-theme.ps1, and mha-theme.txt keep working the
# same way no matter which target you installed with.
$src = Join-Path $PSScriptRoot 'statusline.ps1'
$dest = Join-Path $claudeDir 'statusline.ps1'
Copy-Item -Path $src -Destination $dest -Force

# Also deploy set-theme.ps1 so switching themes later doesn't require the repo checkout.
Copy-Item -Path (Join-Path $PSScriptRoot 'set-theme.ps1') -Destination (Join-Path $claudeDir 'set-theme.ps1') -Force

if ($Target -eq 'ClaudeCode') {
    # The /mha-theme slash command only makes sense inside Claude Code chat,
    # so it's only deployed for that target.
    $commandsDir = Join-Path $claudeDir 'commands'
    New-Item -ItemType Directory -Force -Path $commandsDir | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot 'commands\mha-theme.md') -Destination (Join-Path $commandsDir 'mha-theme.md') -Force

    # "UA Hero Briefing" output style (optional bonus). Copying the file alone
    # does not activate it - Claude Code only applies an output style once you
    # select it via /config or set outputStyle in settings.json - so this is
    # safe to always drop in; it does nothing until you opt in yourself.
    $outputStylesDir = Join-Path $claudeDir 'output-styles'
    New-Item -ItemType Directory -Force -Path $outputStylesDir | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot 'output-styles\ua-hero.md') -Destination (Join-Path $outputStylesDir 'ua-hero.md') -Force
}

# Only prompt for a theme on first install — re-running install.ps1 to pick up a
# script update shouldn't reset a theme you already chose via set-theme.ps1.
# Shared across targets: the same mha-theme.txt drives both.
$themeFile = Join-Path $claudeDir 'mha-theme.txt'
if (-not (Test-Path $themeFile)) {
    & (Join-Path $PSScriptRoot 'set-theme.ps1')
}

if ($Target -eq 'ClaudeCode') {
    $settingsPath = Join-Path $claudeDir 'settings.json'
    if (Test-Path $settingsPath) {
        $settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
    } else {
        $settings = [PSCustomObject]@{}
    }

    $statusLine = [PSCustomObject]@{
        type    = 'command'
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$dest`""
    }

    if ($settings.PSObject.Properties.Name -contains 'statusLine') {
        $settings.statusLine = $statusLine
    } else {
        $settings | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $statusLine
    }

    # Legacy cleanup: older installs wired a gain-xp.ps1 Stop hook to accumulate
    # XP for the Rank segment. Rank is now computed live from weekly usage
    # (rate_limits.seven_day.used_percentage) instead, so that hook and its state
    # file are dead weight — remove them if an earlier install left them behind.
    # Never touches hooks other tools/plugins have configured on Stop.
    $legacyGainXpDest = Join-Path $claudeDir 'gain-xp.ps1'
    $legacyStateFile = Join-Path $claudeDir 'mha-statusline-state.json'
    if ($settings.PSObject.Properties.Name -contains 'hooks' -and $settings.hooks.PSObject.Properties.Name -contains 'Stop') {
        $legacyGainXpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$legacyGainXpDest`""
        $kept = @(@($settings.hooks.Stop) | Where-Object {
            -not (@($_.hooks) | Where-Object { $_.command -eq $legacyGainXpCommand })
        })
        if ($kept.Count -lt @($settings.hooks.Stop).Count) {
            $settings.hooks.Stop = $kept
            Write-Host "Removed legacy gain-xp.ps1 Stop hook (Rank is now weekly-usage-based)." -ForegroundColor Yellow
        }
    }
    Remove-Item -Path $legacyGainXpDest, $legacyStateFile -Force -ErrorAction SilentlyContinue

    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

    Write-Host "Installed to $dest" -ForegroundColor Green
    Write-Host "settings.json updated: $settingsPath" -ForegroundColor Green
    Write-Host "Restart Claude Code (or open a new session) to see the new statusline." -ForegroundColor Yellow
    Write-Host "Optional: try the 'UA Hero Briefing' output style via /config (not enabled by default)." -ForegroundColor Yellow
} else {
    # Shell target: hook the PowerShell prompt itself instead of any one
    # tool's config. CurrentUserAllHosts covers powershell.exe, pwsh, and the
    # VS Code/Windows Terminal integrated console alike, so it fires no
    # matter which terminal Codex, a local LLM CLI, or anything else runs in.
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath) {
        Write-Host "Couldn't resolve a PowerShell profile path (`$PROFILE.CurrentUserAllHosts came back empty) -- this host may not support one." -ForegroundColor Red
        Write-Host "Hook it in by hand instead: add a 'prompt' function to your profile that runs `"$dest`" -- see the README's Codex/local-LLM section." -ForegroundColor Yellow
        exit 1
    }
    $profileDir = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath | Out-Null
    }

    $beginMarker = '# >>> mha-statusline >>>'
    $endMarker   = '# <<< mha-statusline <<<'

    # Single-quoted so none of this expands now — it's PowerShell source that
    # must only run later, inside the profile, each time a prompt is drawn.
    $blockTemplate = @'
# >>> mha-statusline >>>
# My Hero Academia statusline for any terminal — Codex CLI, a local LLM CLI
# (ollama run, etc.), or a plain shell. Installed by mha-statusline's
# install.ps1 -Target Shell. Change theme: set-theme.ps1 in the same folder.
# Remove: install.ps1's repo has an uninstall.ps1 that strips this block.
if (-not (Test-Path variable:global:MhaStatuslinePrevPrompt)) {
    $global:MhaStatuslinePrevPrompt = $function:prompt
}
function prompt {
    & "__MHA_STATUSLINE_PATH__"
    Write-Host ''
    & $global:MhaStatuslinePrevPrompt
}
# <<< mha-statusline <<<
'@
    $block = $blockTemplate.Replace('__MHA_STATUSLINE_PATH__', $dest)

    # Idempotent: strip any block a previous install left, then append fresh,
    # so re-running -Target Shell after a script update doesn't stack hooks.
    $existing = Get-Content -Raw -Path $profilePath -ErrorAction SilentlyContinue
    if (-not $existing) { $existing = '' }
    $pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)
    $existing = [regex]::Replace($existing, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline).TrimEnd()

    $newContent = if ($existing) { "$existing`r`n`r`n$block`r`n" } else { "$block`r`n" }
    Set-Content -Path $profilePath -Value $newContent -Encoding utf8

    Write-Host "Installed to $dest" -ForegroundColor Green
    Write-Host "Hooked into your PowerShell prompt: $profilePath" -ForegroundColor Green
    Write-Host "Open a new PowerShell/pwsh session (or a new Codex CLI/local-LLM terminal tab) to see it." -ForegroundColor Yellow
    Write-Host "It's a shell prompt hook, not tied to any one AI tool -- it'll show up in Codex CLI, ollama run, or a plain shell alike." -ForegroundColor Yellow
    Write-Host "No Cooldown segment in this mode (rate_limits only exist in Claude Code's own JSON payload) -- Quirk/Agency/Rank/motto still show." -ForegroundColor Yellow
}

Write-Host "Change theme anytime: $(if ($Target -eq 'ClaudeCode') { 'type /mha-theme in Claude Code, or run ' } else { 'run ' })powershell -NoProfile -ExecutionPolicy Bypass -File `"$claudeDir\set-theme.ps1`"" -ForegroundColor Yellow
Write-Host "Default theme is 'auto' -- it cycles the whole roster every 5 minutes. Pin one with $(if ($Target -eq 'ClaudeCode') { '/mha-theme <name>' } else { 'set-theme.ps1 -Theme <name>' }) any time." -ForegroundColor Yellow
Write-Host "Go beyond, Plus Ultra! 💪" -ForegroundColor Magenta
