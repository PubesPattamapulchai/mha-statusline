# Removes the commit-hero-names hook from the current directory's repo,
# restoring the most recent pre-install backup if install-git-hook.ps1 made
# one (i.e. you had a different prepare-commit-msg hook before installing
# this one).
#
# Usage: cd into the target repo, then run this script.
$ErrorActionPreference = 'Stop'

$repoRoot = Get-Location
$hooksDir = Join-Path $repoRoot '.git\hooks'
$dstShim = Join-Path $hooksDir 'prepare-commit-msg'
$dstLogic = Join-Path $hooksDir 'prepare-commit-msg.ps1'

if (-not (Test-Path $dstShim) -or -not (Select-String -Path $dstShim -Pattern 'mha-statusline commit-hero-names' -Quiet -ErrorAction SilentlyContinue)) {
    Write-Host "No commit-hero-names hook found in $hooksDir -- nothing to do." -ForegroundColor Yellow
    exit 0
}

Remove-Item -Path $dstShim -Force
if (Test-Path $dstLogic) { Remove-Item -Path $dstLogic -Force }

$backups = Get-ChildItem -Path $hooksDir -Filter 'prepare-commit-msg.bak-*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending
if ($backups) {
    $latest = $backups[0]
    Move-Item -Path $latest.FullName -Destination $dstShim -Force
    Write-Host "Restored previous hook from $($latest.Name)" -ForegroundColor Green
} else {
    Write-Host "Removed commit-hero-names hook from $hooksDir" -ForegroundColor Green
}
