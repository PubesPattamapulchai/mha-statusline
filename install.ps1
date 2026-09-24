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

    # Aizawa-sensei review subagent + /aizawa-review command (optional bonus,
    # same "just copy the file" install as everything else here).
    $agentsDir = Join-Path $claudeDir 'agents'
    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    Copy-Item -Path (Join-Path $PSScriptRoot 'agents\aizawa.md') -Destination (Join-Path $agentsDir 'aizawa.md') -Force
    Copy-Item -Path (Join-Path $PSScriptRoot 'commands\aizawa-review.md') -Destination (Join-Path $commandsDir 'aizawa-review.md') -Force
}

# And villain-alert.ps1, the Notification hook that reskins "Claude needs
# your attention" notifications as themed alerts.
$villainAlertDest = Join-Path $claudeDir 'villain-alert.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'villain-alert.ps1') -Destination $villainAlertDest -Force

# And the Hermes Auto telemetry forwarder (Phase 3B pre-hardening item #1):
# the shared POST core plus its Notification-hook entry point. Always
# deployed, like villain-alert.ps1/agency-sim.ps1 above -- it's opt-in via
# hermes-forward.json/env var, so copying it in is a no-op for anyone not
# running Hermes Auto Control Center locally. statusline.ps1 itself calls
# hermes-forward-send.ps1 directly for the statusline side (see its own
# comment near the top), no separate deploy step needed for that half.
$hermesSendDest = Join-Path $claudeDir 'hermes-forward-send.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'hermes-forward-send.ps1') -Destination $hermesSendDest -Force
$hermesNotificationDest = Join-Path $claudeDir 'hermes-forward-notification.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'hermes-forward-notification.ps1') -Destination $hermesNotificationDest -Force

# Default config, only if one doesn't already exist -- same "don't clobber a
# choice already made" rule mha-theme.txt follows on reinstall. Disabled out
# of the box; flip `enabled` to `true` (and `url` if not on the default
# port) to turn it on. See README's "Hermes Auto telemetry forwarding".
$hermesConfigDest = Join-Path $claudeDir 'hermes-forward.json'
if (-not (Test-Path $hermesConfigDest)) {
    [PSCustomObject]@{ enabled = $false; url = 'http://127.0.0.1:8000' } |
        ConvertTo-Json | Set-Content -Path $hermesConfigDest -Encoding utf8
}

# And agency-sim.ps1 (Phase 1 of the Agency Sim companion feature: logs a
# patrol/villain/mission event per turn, no narration built on top yet -
# see docs/PROJECT-IDEAS.md #6) plus the /patrol command that reports it.
$agencySimDest = Join-Path $claudeDir 'agency-sim.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'agency-sim.ps1') -Destination $agencySimDest -Force
Copy-Item -Path (Join-Path $PSScriptRoot 'commands\patrol.md') -Destination (Join-Path $commandsDir 'patrol.md') -Force

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

    # Wire villain-alert.ps1 into the Notification hook, matched to only the
    # "Claude actually needs you" notification types -- not every notification,
    # to avoid alert fatigue. Same merge-safe pattern as the Stop hook above.
    if ($settings.PSObject.Properties.Name -notcontains 'hooks') {
        $settings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value ([PSCustomObject]@{})
    }
    if ($settings.hooks.PSObject.Properties.Name -notcontains 'Notification') {
        $settings.hooks | Add-Member -MemberType NoteProperty -Name 'Notification' -Value @()
    }
    $villainAlertCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$villainAlertDest`""
    $villainAlertMatcher = 'permission_prompt|agent_needs_input|idle_prompt'
    $villainAlreadyWired = $false
    foreach ($entry in @($settings.hooks.Notification)) {
        foreach ($h in @($entry.hooks)) {
            if ($h.command -eq $villainAlertCommand) { $villainAlreadyWired = $true }
        }
    }
    if (-not $villainAlreadyWired) {
        $notificationEntry = [PSCustomObject]@{
            matcher = $villainAlertMatcher
            hooks   = @([PSCustomObject]@{ type = 'command'; command = $villainAlertCommand; timeout = 5 })
        }
        $settings.hooks.Notification = @(@($settings.hooks.Notification) + $notificationEntry)
    }

    # Wire hermes-forward-notification.ps1 as its own, separate Notification
    # hook entry -- alongside villain-alert.ps1's entry above, never
    # replacing or editing it. Unlike villain-alert.ps1 (matched to just the
    # "needs you" notification types, to avoid alert fatigue), this matches
    # every notification type: it's silent telemetry, not a user-facing
    # alert, and Hermes Auto's own /telemetry/claude/notification endpoint is
    # the place to decide what matters, not this script. Opt-in via
    # hermes-forward.json/$env:MHA_HERMES_ENABLED, so wiring this hook in
    # unconditionally costs nothing when disabled -- see
    # hermes-forward-send.ps1's own early "disabled" exit.
    $hermesNotificationCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$hermesNotificationDest`""
    $hermesNotificationAlreadyWired = $false
    foreach ($entry in @($settings.hooks.Notification)) {
        foreach ($h in @($entry.hooks)) {
            if ($h.command -eq $hermesNotificationCommand) { $hermesNotificationAlreadyWired = $true }
        }
    }
    if (-not $hermesNotificationAlreadyWired) {
        $hermesNotificationEntry = [PSCustomObject]@{
            matcher = '.*'
            hooks   = @([PSCustomObject]@{ type = 'command'; command = $hermesNotificationCommand; timeout = 5 })
        }
        $settings.hooks.Notification = @(@($settings.hooks.Notification) + $hermesNotificationEntry)
    }

    # Wire agency-sim.ps1 as its own separate Stop hook entry (alongside any
    # other Stop hooks already there, not replacing them) - same merge-safe pattern.
    $agencySimCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$agencySimDest`""
    $agencySimAlreadyWired = $false
    foreach ($entry in @($settings.hooks.Stop)) {
        foreach ($h in @($entry.hooks)) {
            if ($h.command -eq $agencySimCommand) { $agencySimAlreadyWired = $true }
        }
    }
    if (-not $agencySimAlreadyWired) {
        $agencySimEntry = [PSCustomObject]@{
            hooks = @([PSCustomObject]@{ type = 'command'; command = $agencySimCommand; timeout = 10 })
        }
        $settings.hooks.Stop = @(@($settings.hooks.Stop) + $agencySimEntry)
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

    Write-Host "Installed to $dest" -ForegroundColor Green
    Write-Host "settings.json updated: $settingsPath" -ForegroundColor Green
    Write-Host "Restart Claude Code (or open a new session) to see the new statusline." -ForegroundColor Yellow
    Write-Host "Optional: try the 'UA Hero Briefing' output style via /config (not enabled by default)." -ForegroundColor Yellow
    Write-Host "Try the strict reviewer: /aizawa-review" -ForegroundColor Yellow
    Write-Host "Villain alerts wired: a bell + desktop notification fires when Claude needs your input." -ForegroundColor Yellow
    Write-Host "Hermes Auto telemetry forwarding: installed but OFF by default -- edit $hermesConfigDest to turn it on (see README)." -ForegroundColor Yellow
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
Write-Host "Default theme is 'auto' -- it cycles the whole roster, a full lap every 5 hours. Pin one with $(if ($Target -eq 'ClaudeCode') { '/mha-theme <name>' } else { 'set-theme.ps1 -Theme <name>' }) any time." -ForegroundColor Yellow
if ($Target -eq 'ClaudeCode') {
    Write-Host "Agency Sim (experimental): patrol/villain/mission events now logged per turn. Check them with /patrol." -ForegroundColor Yellow
}
Write-Host "Go beyond, Plus Ultra! 💪" -ForegroundColor Magenta
