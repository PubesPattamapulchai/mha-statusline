# Claude Code "Notification" hook -- forwards the raw Notification-hook JSON
# to a local Hermes Auto Control Center instance for telemetry (Phase 3B
# pre-hardening item #1: https://<sibling project, not in this repo>).
#
# This is a SEPARATE, standalone Notification hook entry from
# villain-alert.ps1 -- Claude Code supports multiple hook commands per event,
# so install.ps1 registers this alongside villain-alert.ps1 rather than
# touching it. This script never reads villain-alert.ps1's output and never
# writes anything villain-alert.ps1 (or Claude Code) would see, so it cannot
# interfere with the bell/desktop-notification behavior that hook documents.
#
# Disabled by default -- see README's "Hermes Auto telemetry forwarding"
# section. Opt in via ~/.claude/hermes-forward.json (`enabled: true`) or
# $env:MHA_HERMES_ENABLED=1.
#
# Notification hooks are special: per Claude Code's docs (see
# villain-alert.ps1's own header comment), stdout/stderr and exit code are
# ALL ignored for this event. So being careful here isn't about stdout
# contamination -- it's purely about never adding latency and never
# throwing. This script writes nothing to stdout, never sets a non-zero exit
# code on purpose, and hands the actual network call off to a fully detached
# background process (hermes-forward-send.ps1, same mechanism
# statusline.ps1 uses) so this hook process itself returns almost
# immediately either way.
$ErrorActionPreference = 'SilentlyContinue'

try {
    $hermesSender = Join-Path $PSScriptRoot 'hermes-forward-send.ps1'
    if (Test-Path $hermesSender) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8NoBom)
        $raw = $stdinReader.ReadToEnd()
        if ($raw) {
            $hermesPayloadFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mha-hermes-$([guid]::NewGuid().ToString('N')).json")
            Set-Content -Path $hermesPayloadFile -Value $raw -Encoding utf8 -NoNewline

            $hermesHostExe = (Get-Process -Id $PID).Path
            $hermesArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $hermesSender, '-Endpoint', 'notification', '-PayloadFile', $hermesPayloadFile)
            $hermesStartParams = @{ FilePath = $hermesHostExe; ArgumentList = $hermesArgs }
            if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                $hermesStartParams.WindowStyle = 'Hidden'
            }
            Start-Process @hermesStartParams -ErrorAction SilentlyContinue | Out-Null
        }
    }
} catch {
    # Never throw -- Notification hooks must not fail because of this.
}
# No stdout, no explicit exit code -- falls through and exits 0, same
# no-visible-output contract villain-alert.ps1 documents for this event.
