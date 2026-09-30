# steps-ps/99-finish.ps1 — final wiring + health report.
#
#   - ensures $DiverBin is on the user PATH (HKCU, idempotent)
#   - probes every binary the cascade manages (step manifests) and reports
#     present vs missing
#   - lists $DiverUnsupported binaries honestly (no clean rootless path)
#   - prints installed versions of the key binaries
#   - runs nvim --headless :checkhealth and summarises errors

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
. (Join-Path $LibDir 'toolchain.ps1')
Initialize-DiverPlatform

Add-DiverUserPath

# ------------------------------------------------- toolchain manifest ---
Write-Host ''
Write-DiverLog 'toolchain audit (binaries the cascade manages):'
$manifestDir = Join-Path $DiverDataDir 'diver\install\manifest.d'
$present = 0
$missing = @()
if (Test-Path -LiteralPath $manifestDir) {
    $bins = Get-ChildItem -LiteralPath $manifestDir -Filter '*.txt' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-Content -LiteralPath $_.FullName } |
        Where-Object { $_ -ne '' } | Sort-Object -Unique
    foreach ($b in $bins) {
        if (Test-DiverCommand $b) { $present++ } else { $missing += $b }
    }
    Write-DiverOk "$present managed binaries on PATH"
    if ($missing.Count -gt 0) {
        Write-DiverWarn "$($missing.Count) managed binaries still missing:"
        $missing | Select-Object -First 40 | ForEach-Object { Write-Host "    $_" }
        if ($missing.Count -gt 40) { Write-DiverWarn "... and $($missing.Count - 40) more" }
    }
} else {
    Write-DiverWarn 'no step manifests found (did 60/70/80 run?)'
}

# ------------------------------------------------------- unsupported ---
Write-Host ''
Write-DiverLog 'known-unsupported on a rootless install (not attempted):'
$DiverUnsupported | ForEach-Object { Write-Host "    $_" }

# ------------------------------------------------------------- versions ---
Write-Host ''
Write-DiverLog 'installed versions:'
foreach ($b in @('nvim', 'git', 'lua-language-server', 'node', 'pnpm', 'uv', 'go', 'cargo', 'python', 'java')) {
    if (Test-DiverCommand $b) {
        $ver = (& $b --version 2>&1 | Select-Object -First 1)
        Write-Host ("  {0,-20} {1}" -f $b, $ver)
    } else {
        Write-Host ("  {0,-20} (missing)" -f $b)
    }
}

# ----------------------------------------------------------- checkhealth ---
Write-Host ''
if (Test-DiverCommand 'nvim') {
    Write-DiverLog 'running :checkhealth (headless)'
    $log = Join-Path $DiverTempDir 'checkhealth.log'
    & nvim --headless -c 'checkhealth' -c 'q!' > $log 2>&1 | Out-Null
    $lines = Get-Content -LiteralPath $log -ErrorAction SilentlyContinue
    $errors = @($lines | Where-Object { $_ -match 'ERROR' }).Count
    $warnings = @($lines | Where-Object { $_ -match 'WARNING' }).Count
    if ($errors -eq 0) {
        Write-DiverOk "checkhealth: 0 errors, $warnings warnings"
    } else {
        Write-DiverWarn "checkhealth: $errors errors, $warnings warnings — see $log"
    }
    $dest = Join-Path $DiverDataDir 'install-checkhealth.log'
    Copy-Item -LiteralPath $log -Destination $dest -Force
    Write-DiverLog "full checkhealth log → $dest"
}

Write-Host ''
Write-DiverOk 'Diver install complete — open a NEW shell and run: nvim'
