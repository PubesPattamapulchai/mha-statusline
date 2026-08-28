# Installs the commit-hero-names prepare-commit-msg hook into whatever git
# repo you run this from. Unlike install.ps1 (which targets ~/.claude once),
# this targets .git/hooks/ in the CURRENT directory -- run it from inside
# each repo you want the hook in, not from mha-statusline itself (unless
# you want it here too, which is fine).
#
# Usage:
#   cd C:\path\to\some-other-repo
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\path\to\mha-statusline\install-git-hook.ps1
$ErrorActionPreference = 'Stop'

$repoRoot = Get-Location
$gitDir = Join-Path $repoRoot '.git'
if (-not (Test-Path $gitDir)) {
    Write-Host "Not a git repository: no .git found in $repoRoot" -ForegroundColor Red
    Write-Host "cd into the repo you want this hook installed in, then re-run." -ForegroundColor Yellow
    exit 1
}

$hooksDir = Join-Path $gitDir 'hooks'
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

$srcShim = Join-Path $PSScriptRoot 'hooks\prepare-commit-msg'
$srcLogic = Join-Path $PSScriptRoot 'hooks\prepare-commit-msg.ps1'
$dstShim = Join-Path $hooksDir 'prepare-commit-msg'
$dstLogic = Join-Path $hooksDir 'prepare-commit-msg.ps1'

# Back up any existing prepare-commit-msg hook that isn't already ours --
# never silently clobber another tool's hook (husky, pre-commit, etc.).
if ((Test-Path $dstShim) -and -not (Select-String -Path $dstShim -Pattern 'mha-statusline commit-hero-names' -Quiet)) {
    $backup = "$dstShim.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -Path $dstShim -Destination $backup -Force
    Write-Host "Existing prepare-commit-msg hook backed up to $backup" -ForegroundColor Yellow
}

Copy-Item -Path $srcShim -Destination $dstShim -Force
Copy-Item -Path $srcLogic -Destination $dstLogic -Force

Write-Host "Installed commit-hero-names into $hooksDir" -ForegroundColor Green
Write-Host 'Try it: git commit -m "feat: something" --allow-empty' -ForegroundColor Yellow
