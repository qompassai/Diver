# scripts/install/lib-ps/common.ps1
# Shared helpers for the Diver rootless install cascade on native Windows.
# Dot-sourced by every step-ps/*.ps1. Installs nothing itself.
#
# Windows PowerShell 5.1 compatible (no PS7-only syntax).
#
# Layout (all user-local, no admin/UAC):
#   $DiverPrefix    = $env:LOCALAPPDATA\Diver
#   $DiverBin       = $DiverPrefix\bin
#   $DiverConfigDir = $env:LOCALAPPDATA\nvim   (nvim's Windows config dir)
#   $DiverDataDir   = $env:LOCALAPPDATA\nvim-data

$ErrorActionPreference = 'Stop'

function Write-DiverLog  { param([string]$Message) Write-Host "→ $Message" }
function Write-DiverOk   { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-DiverWarn { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-DiverErr  { param([string]$Message) Write-Host "!! $Message" -ForegroundColor Red }
function Write-DiverStep { param([string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

function Test-DiverCommand {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

function Initialize-DiverPlatform {
    $localAppData = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        $localAppData = Join-Path $HOME 'AppData\Local'
    }
    $script:DiverPrefix    = Join-Path $localAppData 'Diver'
    $script:DiverBin       = Join-Path $script:DiverPrefix 'bin'
    $script:DiverConfigDir = Join-Path $localAppData 'nvim'
    $script:DiverDataDir   = Join-Path $localAppData 'nvim-data'
    $script:DiverTempDir   = Join-Path ([System.IO.Path]::GetTempPath()) ("diver-install-$PID")

    foreach ($dir in @($script:DiverPrefix, $script:DiverBin, $script:DiverDataDir, $script:DiverTempDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
    }

    # This process sees user-local bins first.
    $env:Path = "$script:DiverBin;$env:Path"
    $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
}

function Invoke-DiverDownload {
    param(
        [string]$Url,
        [string]$OutFile
    )
    Write-DiverLog "fetching $(Split-Path -Leaf $Url)"
    # curl.exe ships with Windows 10+ and is far faster than Invoke-WebRequest.
    if (Test-DiverCommand 'curl.exe') {
        & curl.exe -L --fail --retry 3 -o $OutFile $Url
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
    if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $OutFile)) {
        throw "download failed: $Url"
    }
}

function Expand-DiverArchive {
    param(
        [string]$Archive,
        [string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }
    if ($Archive -match '\.zip$') {
        Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
    } elseif ($Archive -match '\.tar\.gz$|\.tgz$') {
        # tar.exe ships with Windows 10 1803+.
        & tar.exe -xzf $Archive -C $Destination
    } else {
        throw "unknown archive format: $Archive"
    }
}

function Add-DiverUserPath {
    param([string]$Dir = $script:DiverBin)
    # Idempotently prepend $Dir to the *user* PATH (HKCU — no admin).
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrWhiteSpace($current)) { $current = '' }
    $parts = $current -split ';' | Where-Object { $_ -ne '' }
    if ($parts -notcontains $Dir) {
        $new = "$Dir;$current"
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-DiverLog "PATH updated for current user (new shells pick it up)"
    }
}

function Install-DiverWingetPackage {
    param(
        [string]$Id,
        [string]$LogName
    )
    if (-not (Test-DiverCommand 'winget.exe')) {
        Write-DiverWarn "winget not found — cannot install $LogName automatically"
        return $false
    }
    Write-DiverLog "winget installing $LogName ($Id) — user scope, no admin"
    & winget.exe install --scope user -e --id $Id `
        --accept-source-agreements --accept-package-agreements `
        --silent 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Get-DiverRepoRoot {
    # The checkout containing scripts/install.ps1.
    # The orchestrator (install.ps1) exports $env:DIVER_REPO_ROOT; fall back
    # to walking up three levels from this file
    # (scripts/install/lib-ps/common.ps1 → scripts → repo).
    if (-not [string]::IsNullOrWhiteSpace($env:DIVER_REPO_ROOT)) {
        return $env:DIVER_REPO_ROOT
    }
    $here = Split-Path -Parent $PSCommandPath   # lib-ps
    $here = Split-Path -Parent $here            # install
    $here = Split-Path -Parent $here            # scripts
    return (Split-Path -Parent $here)            # repo root
}
