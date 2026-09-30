# steps-ps/80-dap.ps1 — install Debug Adapter Protocol backends on Windows.
#
# Mirror of steps/80-dap.sh: debugpy, delve, codelldb, netcoredbg, probe-rs,
# the VS Code JS/PHP debug adapters, and elixir-ls.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
. (Join-Path $LibDir 'toolchain.ps1')
Initialize-DiverPlatform

if ($env:DIVER_INSTALL_DAP -eq '0') {
    Write-DiverLog 'skipping DAP (DIVER_INSTALL_DAP=0)'
    exit 0
}

# --- debugpy (Python) ---
Install-DiverUvTool 'debugpy'

# --- delve (Go) ---
Install-DiverGoPackage 'github.com/go-delve/delve/cmd/dlv@latest' 'dlv'

# --- codelldb (C/C++/Rust) ---
if (-not (Test-DiverCommand 'codelldb')) {
    $url = Get-DiverGhAssetUrl 'vadimcn/codelldb' 'codelldb-.*-win32-x64\.vsix'
    if ($url) {
        $dest = Join-Path $DiverDataDir 'diver\vsix\codelldb'
        $out  = Join-Path $DiverTempDir 'codelldb.vsix'
        try {
            Write-DiverLog 'installing codelldb (VSIX)'
            Invoke-DiverDownload $url $out
            if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
            Expand-DiverArchive $out $dest
            $adapter = Get-ChildItem -LiteralPath $dest -Recurse -File -Filter 'codelldb.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($adapter) {
                $shim = Join-Path $DiverBin 'codelldb.cmd'
                "@echo off`r`n`"$($adapter.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
                Write-DiverOk 'codelldb adapter → codelldb.cmd'
            } else { Write-DiverWarn 'codelldb VSIX extracted but codelldb.exe not found' }
        } catch { Write-DiverWarn "codelldb failed: $_" }
    } else { Write-DiverWarn 'codelldb: no win32-x64 vsix in latest release' }
}
Add-DiverManifest 'codelldb'

# --- netcoredbg (.NET) ---
if (-not (Test-DiverCommand 'netcoredbg')) {
    $url = Get-DiverGhAssetUrl 'Samsung/netcoredbg' 'netcoredbg-win64.*\.zip'
    if ($url) {
        $ncDest = Join-Path $DiverPrefix 'gh\netcoredbg'
        $out = Join-Path $DiverTempDir 'netcoredbg.zip'
        try {
            Write-DiverLog 'installing netcoredbg'
            Invoke-DiverDownload $url $out
            Expand-DiverArchive $out $ncDest
            $inner = Get-ChildItem -LiteralPath $ncDest -Recurse -File -Filter 'netcoredbg.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($inner) {
                $shim = Join-Path $DiverBin 'netcoredbg.cmd'
                "@echo off`r`n`"$($inner.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
                Write-DiverOk 'netcoredbg → netcoredbg.cmd'
            } else { Write-DiverWarn 'netcoredbg extracted but netcoredbg.exe not found' }
        } catch { Write-DiverWarn "netcoredbg failed: $_" }
    } else { Write-DiverWarn 'netcoredbg: no win64 zip in latest release' }
}
Add-DiverManifest 'netcoredbg'

# --- vscode-js-debug (Node) ---
if (-not (Test-DiverCommand 'js-debug-adapter')) {
    $url = Get-DiverGhAssetUrl 'microsoft/vscode-js-debug' '\.vsix$'
    if ($url) {
        $dest = Join-Path $DiverDataDir 'diver\vsix\vscode-js-debug'
        $out  = Join-Path $DiverTempDir 'js-debug.vsix'
        try {
            Write-DiverLog 'installing vscode-js-debug (VSIX)'
            Invoke-DiverDownload $url $out
            if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
            Expand-DiverArchive $out $dest
            $server = Get-ChildItem -LiteralPath $dest -Recurse -File -Filter 'dapDebugServer.js' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($server) {
                $shim = Join-Path $DiverBin 'js-debug-adapter.cmd'
                "@echo off`r`nnode `"$($server.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
                Write-DiverOk 'js-debug-adapter wrapper installed'
            } else { Write-DiverWarn 'vscode-js-debug extracted but dapDebugServer.js not found' }
        } catch { Write-DiverWarn "vscode-js-debug failed: $_" }
    } else { Write-DiverWarn 'vscode-js-debug: no vsix asset in latest release' }
}
Add-DiverManifest 'js-debug-adapter'

# --- php-debug-adapter (Xdebug VS Code extension) ---
if (-not (Test-DiverCommand 'php-debug-adapter')) {
    $url = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/xdebug/vsextensions/vscode-php-debug/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage'
    $dest = Join-Path $DiverDataDir 'diver\vsix\vscode-php-debug'
    $out  = Join-Path $DiverTempDir 'php-debug.vsix'
    try {
        Write-DiverLog 'installing vscode-php-debug (VSIX)'
        Invoke-DiverDownload $url $out
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        Expand-DiverArchive $out $dest
        $server = Get-ChildItem -LiteralPath $dest -Recurse -File -Filter 'phpDebug.js' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($server) {
            $shim = Join-Path $DiverBin 'php-debug-adapter.cmd'
            "@echo off`r`nnode `"$($server.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
            Write-DiverOk 'php-debug-adapter wrapper installed'
        } else { Write-DiverWarn 'vscode-php-debug extracted but phpDebug.js not found (check extension/ prefix)' }
    } catch { Write-DiverWarn "vscode-php-debug failed: $_" }
}
Add-DiverManifest 'php-debug-adapter'

# --- firefox-debug-adapter ---
Install-DiverNpmGlobal 'firefox-debug-adapter'

# --- probe-rs (embedded) ---
Install-DiverCargoPackage 'probe-rs-tools' 'probe-rs'

# --- elixir-ls (also a DAP server for Elixir) ---
if (-not (Test-DiverCommand 'elixir-ls')) {
    $url = Get-DiverGhAssetUrl 'elixir-lsp/elixir-ls' '\.zip$'
    if ($url) {
        $elsDest = Join-Path $DiverPrefix 'gh\elixir-ls'
        $out = Join-Path $DiverTempDir 'elixir-ls.zip'
        try {
            Write-DiverLog 'installing elixir-ls'
            Invoke-DiverDownload $url $out
            Expand-DiverArchive $out $elsDest
            $launcher = Get-ChildItem -LiteralPath $elsDest -Recurse -File -Filter 'language_server.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($launcher) {
                $shim = Join-Path $DiverBin 'elixir-ls.cmd'
                "@echo off`r`ncall `"$($launcher.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
                Write-DiverOk 'elixir-ls → elixir-ls.cmd'
            } else { Write-DiverWarn 'elixir-ls extracted but language_server.bat not found' }
        } catch { Write-DiverWarn "elixir-ls failed: $_" }
    } else { Write-DiverWarn 'elixir-ls: no zip in latest release' }
}
Add-DiverManifest 'elixir-ls'

# --- gdb ---
if (-not (Test-DiverCommand 'gdb')) {
    Write-DiverWarn 'gdb: install via winget (e.g. msys2) or WSL — skipped'
}
Add-DiverManifest 'gdb'

Write-DiverOk 'DAP step done'
