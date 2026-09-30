# steps-ps/90-treesitter.ps1 — install tree-sitter parsers, headlessly.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

if (-not (Test-DiverCommand 'nvim')) { throw 'nvim not on PATH — run step 20 first' }

$Parsers = $env:DIVER_TS_PARSERS
if ([string]::IsNullOrWhiteSpace($Parsers)) {
    # Read the parser list straight out of the installed config.
    $luaDir = Join-Path $DiverConfigDir 'lua'
    if (Test-Path -LiteralPath $luaDir) {
        $found = Get-ChildItem -LiteralPath $luaDir -Recurse -Filter '*.lua' -ErrorAction SilentlyContinue |
            Select-String -Pattern "ensure_installed\s*=\s*\{([^}]*)\}" |
            ForEach-Object { $_.Matches } |
            ForEach-Object { $_.Groups[1].Value } |
            Select-Object -First 1
        if ($found) {
            $Parsers = ([regex]::Matches($found, "'([a-z0-9_+-]+)'") |
                ForEach-Object { $_.Groups[1].Value }) -join ' '
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Parsers)) {
    Write-DiverWarn 'could not find an ensure_installed list in the config'
    Write-DiverWarn "install parsers manually: nvim -c 'TSInstallSync <langs>'"
    exit 0
}

$count = ($Parsers -split '\s+' | Where-Object { $_ -ne '' }).Count
Write-DiverLog "installing $count tree-sitter parsers (headless)"
$log = Join-Path $DiverTempDir 'ts.log'
& nvim --headless -c "TSInstallSync $Parsers" -c 'q' 2>$log | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-DiverOk 'tree-sitter parsers installed'
} else {
    Write-DiverWarn 'parser install reported errors — tail of log:'
    Get-Content -LiteralPath $log -Tail 20 | Write-Host
}
