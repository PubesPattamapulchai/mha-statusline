# Removes the My Hero Academia statusline config — both the Claude Code
# wiring (settings.json's statusLine) and, if present, the shell-prompt hook
# install.ps1 -Target Shell adds for Codex CLI / local-LLM CLIs / a plain
# shell. Leaves statusline.ps1 and friends on disk untouched either way.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
$ErrorActionPreference = 'Stop'
$changed = $false

$settingsPath = Join-Path $HOME '.claude\settings.json'
if (Test-Path $settingsPath) {
    $settings = Get-Content -Raw $settingsPath | ConvertFrom-Json

    if ($settings.PSObject.Properties.Name -contains 'statusLine') {
        $settings.PSObject.Properties.Remove('statusLine')
        Write-Host "Removed statusLine from $settingsPath" -ForegroundColor Green
        $changed = $true
    }

    # Remove only mha-statusline's own Stop hook entry (gain-xp.ps1, a legacy
    # XP accumulator from before Rank became weekly-usage-based) — leave any
    # other hooks in place, since other tools/plugins may share the Stop event.
    if ($settings.PSObject.Properties.Name -contains 'hooks' -and $settings.hooks.PSObject.Properties.Name -contains 'Stop') {
        $gainXpDest = Join-Path $HOME '.claude\gain-xp.ps1'
        $gainXpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$gainXpDest`""
        $kept = @(@($settings.hooks.Stop) | Where-Object {
            -not (@($_.hooks) | Where-Object { $_.command -eq $gainXpCommand })
        })
        if ($kept.Count -lt @($settings.hooks.Stop).Count) {
            $settings.hooks.Stop = $kept
            Write-Host "Removed gain-xp.ps1 from the Stop hook." -ForegroundColor Green
            $changed = $true
        }
    }

    if ($changed) {
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8
    }
} else {
    Write-Host "No settings.json found at $settingsPath — skipping the Claude Code wiring (nothing to remove there)." -ForegroundColor Yellow
}

# Also strip the shell-prompt hook install.ps1 -Target Shell may have added
# (for Codex CLI / local-LLM CLIs / a plain shell). Safe no-op if it was
# never installed that way, or if this host has no $PROFILE at all.
$profilePath = $PROFILE.CurrentUserAllHosts
if ($profilePath -and (Test-Path $profilePath)) {
    $existing = Get-Content -Raw -Path $profilePath
    $beginMarker = '# >>> mha-statusline >>>'
    $endMarker   = '# <<< mha-statusline <<<'
    $pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)
    $singleline = [System.Text.RegularExpressions.RegexOptions]::Singleline
    if ([regex]::IsMatch($existing, $pattern, $singleline)) {
        $updated = [regex]::Replace($existing, $pattern, '', $singleline).TrimEnd()
        Set-Content -Path $profilePath -Value $(if ($updated) { "$updated`r`n" } else { '' }) -Encoding utf8
        Write-Host "Removed the shell-prompt hook from $profilePath" -ForegroundColor Green
        $changed = $true
    }
}

# The "UA Hero Briefing" output style is an inert opt-in extra (see
# install.ps1) — remove the file regardless, but only nudge about switching
# away from it in settings.json if it was actually selected.
$outputStylePath = Join-Path $HOME '.claude\output-styles\ua-hero.md'
if (Test-Path $outputStylePath) {
    Remove-Item -Path $outputStylePath -Force
    Write-Host "Removed $outputStylePath" -ForegroundColor Green
    if ($settings -and $settings.outputStyle -eq 'UA Hero Briefing') {
        Write-Host "Note: outputStyle in settings.json was still set to 'UA Hero Briefing' - switch it via /config, since the file backing it is now gone." -ForegroundColor Yellow
    }
    $changed = $true
}

if ($changed) {
    Write-Host "Restart Claude Code, or open a new terminal session, to see the change." -ForegroundColor Yellow
} else {
    Write-Host "Nothing to remove." -ForegroundColor Yellow
}
Write-Host "statusline.ps1, set-theme.ps1, commands\mha-theme.md, and any saved theme (mha-theme.txt) are left on disk — delete them manually from $(Join-Path $HOME '.claude') if you want mha-statusline fully gone." -ForegroundColor Yellow
