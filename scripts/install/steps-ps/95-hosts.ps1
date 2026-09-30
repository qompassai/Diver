# steps-ps/95-hosts.ps1 — Neovim remote-plugin providers + lua-language-server.
#
# node/python providers user-locally, plus the lua-language-server prebuilt
# binary and the `lua_ls` shim the config expects.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

if (Test-DiverCommand 'pnpm') {
    & pnpm add -g neovim 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-DiverLog 'node provider: pnpm neovim ok' }
    else { Write-DiverWarn 'node provider: pnpm add -g neovim failed' }
} elseif (Test-DiverCommand 'npm') {
    & npm install -g neovim 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-DiverLog 'node provider: npm neovim ok' }
    else { Write-DiverWarn 'node provider: npm install -g neovim failed' }
} else {
    Write-DiverWarn 'node provider skipped: no pnpm/npm'
}

# pynvim is a library, not a CLI app — use a dedicated venv under the Diver
# data dir instead of `uv tool install`.
if (Test-DiverCommand 'uv.exe') {
    $venv = Join-Path $DiverDataDir 'diver\venvs\pynvim'
    $venvPy = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPy)) {
        & uv.exe venv $venv 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $env:VIRTUAL_ENV = $venv
            & uv.exe pip install pynvim 2>$null | Out-Null
            Remove-Item Env:\VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        if ($LASTEXITCODE -eq 0) { Write-DiverLog 'python provider: uv venv pynvim ok' }
        else { Write-DiverWarn 'python provider: uv venv/pip install pynvim failed' }
    }
    $pyOk = $false
    if (Test-Path -LiteralPath $venvPy) {
        & $venvPy -c 'import pynvim' 2>$null
        $pyOk = ($LASTEXITCODE -eq 0)
    }
    if ($pyOk) {
        Write-DiverLog "python provider: pynvim importable at $venvPy"
    }
} elseif (Test-DiverCommand 'pip') {
    & pip install --user pynvim 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-DiverLog 'python provider: pip pynvim ok' }
    else { Write-DiverWarn 'python provider: pip install pynvim failed' }
} else {
    Write-DiverWarn 'python provider skipped: no uv/pip'
}

# lua-language-server prebuilt binary.
$ver  = '3.15.0'
$url  = "https://github.com/LuaLS/lua-language-server/releases/download/$ver/lua-language-server-$ver-win32-x64.zip"
$dest = Join-Path $DiverPrefix "lua-language-server-$ver"
$bin  = Join-Path $dest 'bin\lua-language-server.exe'
if (-not (Test-Path -LiteralPath $bin)) {
    $out = Join-Path $DiverTempDir 'lua-ls.zip'
    try {
        Write-DiverLog "installing lua-language-server $ver → $dest"
        Invoke-DiverDownload $url $out
        Expand-DiverArchive $out $dest
    } catch {
        Write-DiverWarn "lua-language-server download failed: $_"
    }
}
if (Test-Path -LiteralPath $bin) {
    $shim = Join-Path $DiverBin 'lua_ls.cmd'
    "@echo off`r`n`"$bin`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
    $shim2 = Join-Path $DiverBin 'lua-language-server.cmd'
    "@echo off`r`n`"$bin`" %*" | Set-Content -LiteralPath $shim2 -Encoding Ascii
    Write-DiverLog 'lua-language-server + lua_ls shim installed'
}

Write-DiverOk 'providers step done'
