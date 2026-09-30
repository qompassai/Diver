# steps-ps/20-neovim.ps1 — install Neovim nightly, rootlessly.
#
# Default: download the prebuilt nvim-win64.zip nightly into
# $env:LOCALAPPDATA\Diver\nvim-nightly and shim nvim.exe into bin.
# -Source: from-source build (needs VS Build Tools + cmake + ninja).

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

function Install-NvimBinary {
    $url  = 'https://github.com/neovim/neovim/releases/download/nightly/nvim-win64.zip'
    $dest = Join-Path $DiverPrefix 'nvim-nightly'
    $out  = Join-Path $DiverTempDir 'nvim-win64.zip'

    Write-DiverLog "installing prebuilt neovim nightly → $dest"
    if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
    Invoke-DiverDownload $url $out
    # The zip contains a top-level nvim-win64\ dir — strip it on extract.
    $tmp = Join-Path $DiverTempDir 'nvim-extract'
    if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp }
    Expand-DiverArchive $out $tmp
    $inner = Join-Path $tmp 'nvim-win64'
    if (-not (Test-Path -LiteralPath $inner)) { $inner = $tmp }
    New-Item -ItemType Directory -Path $dest | Out-Null
    # Copy the zip's contents (-LiteralPath takes no wildcards, so enumerate).
    Get-ChildItem -LiteralPath $inner | Copy-Item -Destination $dest -Recurse -Force

    # Shim so `nvim` resolves via $DiverBin (already on PATH for this process).
    $shim = Join-Path $DiverBin 'nvim.cmd'
    "@echo off`r`n`"$dest\bin\nvim.exe`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
    Write-DiverOk "neovim installed: $(& "$dest\bin\nvim.exe" --version | Select-Object -First 1)"
}

function Install-NvimSource {
    Write-DiverLog 'building neovim from source (needs VS Build Tools C++ workload)'
    foreach ($t in @('cmake.exe', 'ninja.exe', 'git.exe')) {
        if (-not (Test-DiverCommand $t)) { throw "source build needs $t on PATH" }
    }
    $buildDir = if ($env:BUILD_DIR) { $env:BUILD_DIR } else { Join-Path $HOME 'src\neovim-nightly' }
    if (Test-Path -LiteralPath (Join-Path $buildDir '.git')) {
        & git.exe -C $buildDir fetch --all --tags
    } else {
        & git.exe clone --recursive https://github.com/neovim/neovim $buildDir
    }
    Push-Location $buildDir
    try {
        & git.exe switch master 2>$null
        if ($LASTEXITCODE -ne 0) { & git.exe checkout master }
        # Locate vcvarsall for the MSVC environment.
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (-not (Test-Path -LiteralPath $vswhere)) { throw 'vswhere.exe not found — install VS Build Tools' }
        $vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath).Trim()
        $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
        $dest = Join-Path $DiverPrefix 'nvim-nightly'
        # Run the whole cmake build inside the vcvars environment.
        $buildScript = @"
call "$vcvars" >nul
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .deps
cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo -D CMAKE_INSTALL_PREFIX="$dest"
cmake --build build
cmake --install build
"@
        $batFile = Join-Path $DiverTempDir 'build-nvim.bat'
        $buildScript | Set-Content -LiteralPath $batFile -Encoding Ascii
        & cmd.exe /c $batFile
        if ($LASTEXITCODE -ne 0) { throw 'neovim source build failed' }
        $shim = Join-Path $DiverBin 'nvim.cmd'
        "@echo off`r`n`"$dest\bin\nvim.exe`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
    } finally {
        Pop-Location
    }
    Write-DiverOk 'neovim built from source'
}

if ($env:DIVER_NVIM_SOURCE -eq '1') {
    Install-NvimSource
} else {
    Install-NvimBinary
}

if (-not (Test-DiverCommand 'nvim')) {
    throw 'nvim not on PATH after install'
}
