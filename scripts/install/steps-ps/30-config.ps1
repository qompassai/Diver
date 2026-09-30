# steps-ps/30-config.ps1 — install the Diver config itself, rootlessly.
#
# Ensures $env:LOCALAPPDATA\nvim holds this Diver checkout:
#   already this repo → pull latest (ff-only)
#   missing          → clone (if this repo has a remote) or copy
#   something else   → back up to nvim.bak-<timestamp>, then install
#
# Never deletes without a backup. Safe to re-run.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

$RepoRoot = Get-DiverRepoRoot
$Target   = $DiverConfigDir

function Get-Canonical([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        return (Get-Item -LiteralPath $Path).FullName.TrimEnd('\')
    }
    return $null
}

$canonRepo   = Get-Canonical $RepoRoot
$canonTarget = Get-Canonical $Target

if ($canonTarget -and ($canonTarget -ieq $canonRepo)) {
    Write-DiverLog "config already installed at $Target (this checkout)"
    if (Test-Path -LiteralPath (Join-Path $Target '.git')) {
        $remote = (& git.exe -C $Target remote get-url origin 2>$null)
        if ($remote) {
            Write-DiverLog "pulling latest from $remote"
            & git.exe -C $Target pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Write-DiverWarn 'pull failed — keeping local state' }
        }
    }
    Write-DiverOk 'config in place'
    exit 0
}

$repoRemote = $null
if (Test-Path -LiteralPath (Join-Path $RepoRoot '.git')) {
    $repoRemote = (& git.exe -C $RepoRoot remote get-url origin 2>$null)
}

if (Test-Path -LiteralPath $Target) {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Target.bak-$stamp"
    Write-DiverWarn "existing config at $Target is not this Diver checkout"
    Write-DiverLog "backing up → $backup"
    Move-Item -LiteralPath $Target -Destination $backup
}

if ($repoRemote) {
    Write-DiverLog "cloning $repoRemote → $Target"
    & git.exe clone $repoRemote $Target
    if ($LASTEXITCODE -ne 0) { throw 'clone failed' }
} else {
    Write-DiverLog "copying $RepoRoot → $Target"
    Copy-Item -Recurse -Force -LiteralPath $RepoRoot -Destination $Target
}

Write-DiverOk "Diver config installed at $Target"
