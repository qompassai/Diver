#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diver rootless installer for native Windows (PowerShell cascade orchestrator).

.DESCRIPTION
    Installs the Diver Neovim config and its full tooling without admin rights:
    everything lands under $env:LOCALAPPDATA\Diver and the config goes to
    $env:LOCALAPPDATA\nvim.

    For WSL instead, run scripts/install.sh inside WSL (or scripts/quickstart.ps1).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Only 20,30

.PARAMETER Only
    Run only these steps (numbers like "20" or name fragments like "neovim").

.PARAMETER Skip
    Skip these steps.

.PARAMETER List
    List steps and exit.

.PARAMETER Source
    Build Neovim from source instead of the prebuilt nightly (needs VS Build Tools).
#>
[CmdletBinding()]
param(
    [string[]]$Only = @(),
    [string[]]$Skip = @(),
    [switch]$List,
    [switch]$Source
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$StepsDir  = Join-Path $ScriptDir 'install\steps-ps'
$LibDir    = Join-Path $ScriptDir 'install\lib-ps'

# Steps resolve the repo root from this (see Get-DiverRepoRoot in common.ps1).
$env:DIVER_REPO_ROOT = Split-Path -Parent $ScriptDir

. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

if ($Source) { $env:DIVER_NVIM_SOURCE = '1' }

function Get-DiverSteps {
    Get-ChildItem -LiteralPath $StepsDir -Filter '*.ps1' |
        Where-Object { $_.BaseName -match '^\d' } |
        Sort-Object BaseName |
        ForEach-Object { $_.BaseName }
}

function Test-StepMatch {
    param([string]$Step, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        $fragments = $p -split ','
        foreach ($frag in $fragments) {
            $frag = $frag.Trim()
            if ($Step -like "$frag*" -or $Step -like "*$frag*") { return $true }
        }
    }
    return $false
}

if ($List) {
    Get-DiverSteps | ForEach-Object { Write-Host $_ }
    exit 0
}

Write-DiverStep 'Diver rootless installer (native Windows)'
Write-DiverLog "prefix: $DiverPrefix"
Write-DiverLog "config: $DiverConfigDir"

$failures = @()
$ran = 0

foreach ($step in (Get-DiverSteps)) {
    if ($Only.Count -gt 0 -and -not (Test-StepMatch $step $Only)) { continue }
    if ($Skip.Count -gt 0 -and (Test-StepMatch $step $Skip)) {
        Write-DiverLog "skipping step $step"
        continue
    }

    Write-DiverStep "step $step"
    $ran++
    $stepFile = Join-Path $StepsDir "$step.ps1"
    # Fresh process per step: one step's failure can't corrupt another's state.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $stepFile
    if ($LASTEXITCODE -eq 0) {
        Write-DiverOk "step $step complete"
    } else {
        Write-DiverErr "step $step FAILED (exit $LASTEXITCODE)"
        $failures += $step
    }
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-DiverErr "$($failures.Count) step(s) failed: $($failures -join ', ')"
    Write-DiverErr "Re-run with -Only, e.g.: .\scripts\install.ps1 -Only $($failures[0])"
    exit 1
}
if ($ran -eq 0) {
    Write-DiverWarn 'no steps ran — check -Only/-Skip filters'
    exit 0
}
Write-DiverOk "all $ran step(s) complete — open a NEW shell and run: nvim"
