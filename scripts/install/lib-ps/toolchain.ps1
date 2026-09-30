# scripts/install/lib-ps/toolchain.ps1
# Channel-installer primitives for steps-ps 60/70/80 (formatters, linters, DAP).
#
# Mirrors install/lib/toolchain.sh. Every installer skips when the binary is
# already on PATH, installs user-locally otherwise, and never throws on its
# own (the caller aggregates). Dot-sourced after common.ps1.
#
# Provides:
#   Add-DiverManifest            <bin>...   record binaries this step manages
#   Install-DiverUvTool          <pkg> [bin]
#   Install-DiverNpmGlobal       <pkg> [bin]
#   Install-DiverCargoPackage    <crate> [bin]
#   Install-DiverGoPackage       <module@version> [bin]
#   Install-DiverGhRelease       <owner/repo> <bin> <asset-regex>
#   Install-DiverJavaJar         <url> <name>
#   $DiverUnsupported                       binaries with no clean rootless path

function Add-DiverManifest {
    param([string[]]$Bins)
    $manifestDir = Join-Path $DiverDataDir 'diver\install\manifest.d'
    if (-not (Test-Path -LiteralPath $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir | Out-Null
    }
    # Caller step name: steps-ps/<NN>-<name>.ps1
    $stepName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
    $file = Join-Path $manifestDir "$stepName.txt"
    $existing = @()
    if (Test-Path -LiteralPath $file) { $existing = Get-Content -LiteralPath $file }
    ($existing + $Bins | Where-Object { $_ -ne '' } | Sort-Object -Unique) |
        Set-Content -LiteralPath $file
}

function Invoke-DiverChannelInstall {
    param([string]$Bin, [string]$Label, [scriptblock]$Install)
    if (Test-DiverCommand $Bin) { return }
    Write-DiverLog "installing $Label"
    try {
        & $Install | Out-Null
        if (Test-DiverCommand $Bin) { Write-DiverOk "$Label → $Bin" }
        else { Write-DiverWarn "$Label installed but $Bin not on PATH" }
    } catch {
        Write-DiverWarn "$Label failed (continuing): $_"
    }
}

function Install-DiverUvTool {
    param([string]$Pkg, [string]$Bin = $null)
    if (-not $Bin) { $Bin = $Pkg }
    if (-not (Test-DiverCommand 'uv.exe')) { Write-DiverWarn "skipping ${Pkg}: uv.exe not on PATH"; return }
    Invoke-DiverChannelInstall $Bin "$Pkg (uv)" { & uv.exe tool install $Pkg }
    # uv puts shims in its own bin dir; mirror the shim into $DiverBin so the
    # cascade's single PATH entry covers it (symlinks need admin on Windows).
    if (-not (Test-DiverCommand $Bin)) {
        try {
            $uvBin = (& uv.exe tool dir --bin 2>$null | Select-Object -First 1)
            if ($uvBin) {
                $shim = Get-ChildItem -LiteralPath $uvBin -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.BaseName -eq $Bin } | Select-Object -First 1
                if ($shim) {
                    Copy-Item -LiteralPath $shim.FullName -Destination (Join-Path $DiverBin $shim.Name) -Force
                    Write-DiverLog "mirrored uv shim → $DiverBin\$($shim.Name)"
                }
            }
        } catch { }
    }
    Add-DiverManifest $Bin
}

function Install-DiverNpmGlobal {
    param([string]$Pkg, [string]$Bin = $null)
    if (-not $Bin) { $Bin = $Pkg }
    if (-not (Test-DiverCommand 'npm')) { Write-DiverWarn "skipping ${Pkg}: npm not on PATH"; return }
    Invoke-DiverChannelInstall $Bin "$Pkg (npm)" { & npm install -g $Pkg }
    Add-DiverManifest $Bin
}

function Install-DiverCargoPackage {
    param([string]$Crate, [string]$Bin = $null)
    if (-not $Bin) { $Bin = $Crate }
    if (-not (Test-DiverCommand 'cargo.exe')) { Write-DiverWarn "skipping ${Crate}: cargo.exe not on PATH"; return }
    Invoke-DiverChannelInstall $Bin "$Crate (cargo)" { & cargo.exe install $Crate }
    Add-DiverManifest $Bin
}

function Install-DiverGoPackage {
    param([string]$Module, [string]$Bin = $null)
    if (-not $Bin) { $Bin = $Module }
    if (-not (Test-DiverCommand 'go.exe')) { Write-DiverWarn "skipping ${Module}: go.exe not on PATH"; return }
    $oldGobin = $env:GOBIN
    $env:GOBIN = $DiverBin
    try {
        Invoke-DiverChannelInstall $Bin "$Module (go)" { & go.exe install $Module }
    } finally {
        $env:GOBIN = $oldGobin
    }
    Add-DiverManifest $Bin
}

function Get-DiverGhAssetUrl {
    param([string]$Repo, [string]$AssetRegex)
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    $rel = Invoke-RestMethod -Uri $api -UseBasicParsing
    foreach ($asset in $rel.assets) {
        if ($asset.browser_download_url -match $AssetRegex) {
            return $asset.browser_download_url
        }
    }
    return $null
}

function Install-DiverGhRelease {
    param([string]$Repo, [string]$Bin, [string]$AssetRegex)
    if (Test-DiverCommand $Bin) { Add-DiverManifest $Bin; return }
    $url = Get-DiverGhAssetUrl $Repo $AssetRegex
    if (-not $url) {
        Write-DiverWarn "$Repo`: no release asset matching /$AssetRegex/"
        Add-DiverManifest $Bin
        return
    }
    $dest = Join-Path $DiverPrefix "gh\$Bin"
    $tmp  = Join-Path $DiverTempDir "gh-$Bin"
    foreach ($d in @($dest, $tmp)) {
        if (Test-Path -LiteralPath $d) { Remove-Item -Recurse -Force -LiteralPath $d }
        New-Item -ItemType Directory -Path $d | Out-Null
    }
    $fname = Join-Path $tmp (Split-Path -Leaf $url)
    Write-DiverLog "installing $Bin ← $Repo"
    try {
        Invoke-DiverDownload $url $fname
    } catch {
        Write-DiverWarn "$Bin`: download failed: $_"
        Add-DiverManifest $Bin
        return
    }
    $leaf = Split-Path -Leaf $fname
    if ($leaf -match '\.zip$') {
        Expand-DiverArchive $fname $dest
    } elseif ($leaf -match '\.tar\.gz$|\.tgz$') {
        Expand-DiverArchive $fname $dest
    } else {
        # Single-file binary release.
        $target = Join-Path $DiverBin "$Bin.exe"
        Copy-Item -LiteralPath $fname -Destination $target -Force
        Write-DiverOk "$Bin (single-file release)"
        Add-DiverManifest $Bin
        return
    }
    $found = Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -eq $Bin -and $_.Extension -in @('.exe', '') } |
        Select-Object -First 1
    if ($found) {
        $shim = Join-Path $DiverBin "$Bin.cmd"
        "@echo off`r`n`"$($found.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
        Write-DiverOk "$Bin → $($found.Name)"
    } else {
        Write-DiverWarn "$Bin`: extracted but no '$Bin' executable found under $dest"
    }
    Add-DiverManifest $Bin
}

function Install-DiverJavaJar {
    param([string]$Url, [string]$Name)
    if (-not (Test-DiverCommand 'java.exe')) { Write-DiverWarn "skipping ${Name}: java.exe not on PATH"; return }
    $jarDir = Join-Path $DiverDataDir 'diver\jars'
    if (-not (Test-Path -LiteralPath $jarDir)) { New-Item -ItemType Directory -Path $jarDir | Out-Null }
    $jar = Join-Path $jarDir "$Name.jar"
    if (-not (Test-Path -LiteralPath $jar)) {
        Write-DiverLog "installing $Name (jar)"
        try { Invoke-DiverDownload $Url $jar }
        catch { Write-DiverWarn "${Name}: jar download failed: $_"; return }
    }
    $shim = Join-Path $DiverBin "$Name.cmd"
    "@echo off`r`njava -jar `"$jar`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
    Write-DiverOk "$Name (java -jar wrapper)"
    Add-DiverManifest $Name
}

$DiverUnsupported = @(
    'apkbuild-lint',   # Alpine-only script
    'bashlint',
    'betterleaks',
    'checkpatch.pl',   # kernel.org single-file script
    'desktop-file-validate',
    'fieldalignment',
    'hh_client',       # ships with hhvm/hack; no rootless distribution
    'hlasm_language_server',
    'lint-openapi',
    'llvm-mc',         # only via a full LLVM build
    'matlab',          # proprietary; needs a licensed install
    'mbake',
    'mh_lint',
    'mh_style',
    'nvcc',            # CUDA toolkit installer requires admin
    'panache',
    'psfmt',
    'schemat',
    'secfixes-check',
    'systemd-analyze', # part of systemd; no Windows equivalent
    'unmake'
)
