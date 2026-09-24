# Hermes Auto Control Center telemetry forwarder -- shared POST core.
#
# Not a hook itself and never invoked directly by Claude Code. It's a tiny
# one-off worker that statusline.ps1 (Quirk/statusline hook) and
# hermes-forward-notification.ps1 (Notification hook) each spawn as a fully
# detached background process, handing it a payload already saved to a temp
# file, then move on without waiting for it. That's what keeps both hook
# paths non-blocking: this script does the actual (slow, network-bound) POST
# entirely off of Claude Code's critical path.
#
# Two explicit callers, one tiny shared POST routine between them -- this is
# deliberately NOT a generic "forward any hook" framework: -Endpoint only
# ever takes 'statusline' or 'notification', each mapped to its own fixed,
# documented Hermes Auto ingest path.
#
# Contract: never throws, never writes to stdout/stderr, exit code is never
# inspected by either caller. Failure here must never be visible anywhere.
#
# Usage (always invoked this way, never with input piped in):
#   ... -File hermes-forward-send.ps1 -Endpoint statusline   -PayloadFile <path to raw statusline-hook JSON>
#   ... -File hermes-forward-send.ps1 -Endpoint notification -PayloadFile <path to raw Notification-hook JSON>
param(
    [string]$Endpoint,
    [string]$PayloadFile
)
$ErrorActionPreference = 'SilentlyContinue'

# Config lives next to this script (same ~/.claude/ dir statusline.ps1,
# mha-theme.txt, etc. already use) -- mirrors mha-theme.txt's own
# file-next-to-script + env-var-override pattern instead of inventing a new
# config convention. $env:MHA_HERMES_* always wins over the saved file, same
# precedence $env:MHA_STATUSLINE_THEME has over mha-theme.txt.
function Get-HermesConfig {
    $cfg = [PSCustomObject]@{ Enabled = $false; Url = 'http://127.0.0.1:8000' }
    try {
        $cfgFile = Join-Path $PSScriptRoot 'hermes-forward.json'
        if (Test-Path $cfgFile) {
            $j = Get-Content -Raw $cfgFile | ConvertFrom-Json
            if ($null -ne $j.enabled) { $cfg.Enabled = [bool]$j.enabled }
            if ($j.url) { $cfg.Url = [string]$j.url }
        }
    } catch { }
    if ($null -ne $env:MHA_HERMES_ENABLED -and $env:MHA_HERMES_ENABLED -ne '') {
        $cfg.Enabled = $env:MHA_HERMES_ENABLED -in @('1', 'true', 'True', 'TRUE', 'yes', 'on')
    }
    if ($env:MHA_HERMES_URL) { $cfg.Url = $env:MHA_HERMES_URL }
    return $cfg
}

# Opt-in, minimal debug log -- OFF unless $env:MHA_HERMES_DEBUG is set.
# Never logs payload contents (statusline/notification JSON can carry
# prompt text), only size + outcome, e.g.:
#   forwarded statusline payload: 812 bytes, status 200
#   forward failed: The operation has timed out.
function Write-HermesDebugLog([string]$Message) {
    if (-not $env:MHA_HERMES_DEBUG) { return }
    try {
        $logFile = Join-Path $PSScriptRoot 'hermes-forward-debug.log'
        $line = "$([DateTime]::UtcNow.ToString('o')) [$Endpoint] $Message"
        Add-Content -Path $logFile -Value $line -Encoding utf8
    } catch { }
}

try {
    if ($Endpoint -notin @('statusline', 'notification') -or -not $PayloadFile) {
        # Only ever reached if invoked wrong by hand -- the two real callers
        # always pass both. Nothing to clean up (no known $PayloadFile), just
        # exit quietly.
        exit 0
    }

    $cfg = Get-HermesConfig
    if (-not $cfg.Enabled) {
        Write-HermesDebugLog 'forward skipped: disabled'
        exit 0
    }

    # Hard localhost-only guard: refuse and no-op on anything that isn't
    # loopback, regardless of what's in the config file or env var. Never
    # sends a byte to a non-local host.
    $uri = $null
    try { $uri = [uri]$cfg.Url } catch { $uri = $null }
    if (-not $uri -or -not $uri.IsLoopback) {
        Write-HermesDebugLog "forward skipped: configured URL is not loopback ($($cfg.Url))"
        exit 0
    }

    if (-not (Test-Path $PayloadFile)) {
        Write-HermesDebugLog 'forward skipped: payload file missing'
        exit 0
    }
    $body = Get-Content -Raw -Path $PayloadFile -ErrorAction Stop
    if (-not $body) {
        Write-HermesDebugLog 'forward skipped: empty payload'
        exit 0
    }

    $path = if ($Endpoint -eq 'statusline') { '/telemetry/claude/statusline' } else { '/telemetry/claude/notification' }
    $targetUri = "$($uri.Scheme)://$($uri.Authority)$path"

    try {
        # Payload is forwarded unchanged, as-is, exactly what Claude Code
        # handed the hook on stdin. 2s cap so a stalled/absent Hermes Auto
        # backend can never hang this (already-detached, already-background)
        # process for long.
        $resp = Invoke-WebRequest -Uri $targetUri -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 2 -UseBasicParsing
        Write-HermesDebugLog "forwarded $Endpoint payload: $($body.Length) bytes, status $($resp.StatusCode)"
    } catch {
        Write-HermesDebugLog "forward failed: $($_.Exception.Message)"
    }
} catch {
    # Last-resort guard -- this script must never throw regardless of what
    # goes wrong above.
} finally {
    if ($PayloadFile) { Remove-Item -Path $PayloadFile -Force -ErrorAction SilentlyContinue }
}
