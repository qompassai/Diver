# steps-ps/10-prereqs.ps1 — bootstrap prerequisites, rootlessly (no admin).
#
# Ensures: curl.exe, tar.exe (both ship with Windows 10+), git, and winget.
# Git comes via winget user-scope, or falls back to PortableGit zip.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

$missing = @()
foreach ($cmd in @('curl.exe', 'tar.exe')) {
    if (-not (Test-DiverCommand $cmd)) { $missing += $cmd }
}
if ($missing.Count -gt 0) {
    throw "missing Windows built-ins: $($missing -join ', ') — needs Windows 10 1803+"
}
Write-DiverLog 'curl.exe, tar.exe present'

if (-not (Test-DiverCommand 'git.exe')) {
    Write-DiverLog 'git not found — installing (user scope)'
    $got = Install-DiverWingetPackage 'Git.Git' 'Git'
    if (-not $got) {
        # Fallback: PortableGit zip, no installer at all.
        $ver = '2.53.0'
        $url = "https://github.com/git-for-windows/git/releases/download/v$ver.windows.1/PortableGit-$ver-64-bit.7z.exe"
        $zipUrl = "https://github.com/git-for-windows/git/releases/download/v$ver.windows.1/PortableGit-$ver-64-bit.zip"
        $dest = Join-Path $DiverPrefix "git-$ver"
        $out = Join-Path $DiverTempDir 'portablegit.zip'
        try {
            Invoke-DiverDownload $zipUrl $out
            Expand-DiverArchive $out $dest
            $env:Path = "$dest\bin;$env:Path"
        } catch {
            throw "could not install git: $_ — install Git for Windows manually (user scope)"
        }
    }
    # winget user-scope git lands on PATH for new shells; refresh for this one.
    $gitPaths = @(
        "$env:LOCALAPPDATA\Programs\Git\bin",
        "$env:ProgramFiles\Git\bin"
    )
    foreach ($p in $gitPaths) {
        if ((Test-Path -LiteralPath $p) -and (Test-Path -LiteralPath (Join-Path $p 'git.exe'))) {
            $env:Path = "$p;$env:Path"
            break
        }
    }
}

if (-not (Test-DiverCommand 'git.exe')) {
    throw 'git still not on PATH after install attempts'
}
Write-DiverLog "git: $(& git.exe --version)"

if (-not (Test-DiverCommand 'winget.exe')) {
    Write-DiverWarn 'winget not found — toolchain step will use direct downloads'
} else {
    Write-DiverLog 'winget present (user-scope installs need no admin)'
}

if ($env:DIVER_NVIM_SOURCE -eq '1') {
    Write-DiverWarn 'source build requested: needs Visual Studio Build Tools with C++ workload'
    Write-DiverWarn 'install from https://visualstudio.microsoft.com/downloads/ then re-run'
}

Write-DiverOk 'prerequisites ready'
