# steps-ps/40-toolchains.ps1 — ensure language toolchains exist, rootlessly.
#
# Strategy per toolchain: winget user-scope first (no admin), then a direct
# user-local download as fallback. Best-effort — a toolchain that cannot be
# installed is reported, never fatal. Re-running only fills gaps.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

$skipped = @()

function Install-Go {
    if (Test-DiverCommand 'go.exe') {
        Write-DiverLog "go: $(& go.exe version)"
        return $true
    }
    if (Install-DiverWingetPackage 'GoLang.Go' 'Go') {
        Refresh-Path; if (Test-DiverCommand 'go.exe') { return $true }
    }
    # Fallback: official zip.
    $ver  = '1.25.1'
    $url  = "https://go.dev/dl/go$ver.windows-amd64.zip"
    $dest = Join-Path $DiverPrefix "go-$ver"
    $out  = Join-Path $DiverTempDir 'go.zip'
    try {
        Write-DiverLog "installing Go $ver → $dest"
        Invoke-DiverDownload $url $out
        Expand-DiverArchive $out (Join-Path $DiverTempDir 'gox')
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        Move-Item -LiteralPath (Join-Path $DiverTempDir 'gox\go') -Destination $dest
        $env:Path = "$dest\bin;$env:Path"
        Add-DiverUserPath "$dest\bin"
        return (Test-DiverCommand 'go.exe')
    } catch {
        Write-DiverWarn "Go direct install failed: $_"
        return $false
    }
}

function Install-Rust {
    if (Test-DiverCommand 'cargo.exe') {
        Write-DiverLog "cargo: $(& cargo.exe --version)"
        return $true
    }
    # rustup-init is rootless by design (~/.rustup, ~/.cargo).
    $init = Join-Path $DiverTempDir 'rustup-init.exe'
    try {
        Write-DiverLog 'installing rustup (user scope)'
        Invoke-DiverDownload 'https://win.rustup.rs/x86_64' $init
        & $init -y --profile minimal --no-modify-path | Out-Null
        $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
        return (Test-DiverCommand 'cargo.exe')
    } catch {
        Write-DiverWarn "rustup install failed: $_"
        return $false
    }
}

function Install-Node {
    if (-not (Test-DiverCommand 'node.exe')) {
        if (-not (Install-DiverWingetPackage 'OpenJS.NodeJS.LTS' 'Node.js LTS')) {
            # Fallback: official zip.
            $ver  = '24.11.0'
            $url  = "https://nodejs.org/dist/v$ver/node-v$ver-win-x64.zip"
            $dest = Join-Path $DiverPrefix "node-$ver"
            $out  = Join-Path $DiverTempDir 'node.zip'
            try {
                Write-DiverLog "installing Node $ver → $dest"
                Invoke-DiverDownload $url $out
                Expand-DiverArchive $out (Join-Path $DiverTempDir 'nodex')
                if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
                Move-Item -LiteralPath (Join-Path $DiverTempDir "nodex\node-v$ver-win-x64") -Destination $dest
                $env:Path = "$dest;$env:Path"
                Add-DiverUserPath $dest
            } catch {
                Write-DiverWarn "Node direct install failed: $_"
                return $false
            }
        }
        Refresh-Path
    }
    if (-not (Test-DiverCommand 'node.exe')) { return $false }
    Write-DiverLog "node: $(& node.exe --version)"
    if (-not (Test-DiverCommand 'pnpm')) {
        Write-DiverLog 'enabling pnpm via corepack'
        & corepack enable 2>$null | Out-Null
        & corepack prepare pnpm@latest --activate 2>$null | Out-Null
        if (-not (Test-DiverCommand 'pnpm')) {
            & npm install -g pnpm 2>$null | Out-Null
        }
    }
    if (Test-DiverCommand 'pnpm') { Write-DiverLog "pnpm: $(& pnpm --version)" }
    return $true
}

function Install-Python {
    if (Test-DiverCommand 'python.exe') {
        Write-DiverLog "python: $(& python.exe --version)"
    } else {
        if (-not (Install-DiverWingetPackage 'Python.Python.3.13' 'Python 3.13')) {
            Write-DiverWarn 'Python: winget failed — install from python.org (uncheck "for all users")'
            return $false
        }
        Refresh-Path
        if (-not (Test-DiverCommand 'python.exe')) {
            Write-DiverWarn 'Python installed but not on PATH yet — open a new shell and re-run'
            return $false
        }
    }
    # uv: standalone binary, user-local.
    if (-not (Test-DiverCommand 'uv.exe')) {
        $uvDir = Join-Path $DiverPrefix 'uv'
        $out   = Join-Path $DiverTempDir 'uv.zip'
        try {
            Invoke-DiverDownload 'https://github.com/astral-sh/uv/releases/download/0.8.22/uv-x86_64-pc-windows-msvc.zip' $out
            Expand-DiverArchive $out $uvDir
            $env:Path = "$uvDir;$env:Path"
            Add-DiverUserPath $uvDir
        } catch {
            Write-DiverWarn "uv install failed: $_"
        }
    }
    return $true
}

function Install-Java {
    if (Test-DiverCommand 'java.exe') {
        Write-DiverLog "java: $(& java.exe -version 2>&1 | Select-Object -First 1)"
        return $true
    }
    if (Install-DiverWingetPackage 'EclipseAdoptium.Temurin.21-JDK' 'Temurin JDK 21') {
        Refresh-Path
        return (Test-DiverCommand 'java.exe')
    }
    Write-DiverWarn 'Java: winget failed — needed by java-based LSPs (jdtls, apex)'
    return $false
}

function Refresh-Path {
    # Pick up user-scope winget installs in this process.
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:Path = "$DiverBin;$userPath;$machinePath"
    # Common winget user install locations:
    foreach ($p in @("$env:LOCALAPPDATA\Programs", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages")) {
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { $env:Path = "$($_.FullName);$env:Path" }
        }
    }
}


if (-not (Install-Go))     { $skipped += 'go' }
if (-not (Install-Rust))   { $skipped += 'rust' }
if (-not (Install-Node))   { $skipped += 'node' }
if (-not (Install-Python)) { $skipped += 'python' }
if (-not (Install-Java))   { $skipped += 'java' }

if (Test-DiverCommand 'ruby.exe') {
    Write-DiverLog "ruby: $(& ruby.exe --version)"
} else {
    $skipped += 'ruby (winget: RubyInstallerTeam.RubyWithDevKit.3.4)'
}

Write-Host ''
if ($skipped.Count -gt 0) {
    Write-DiverWarn "toolchains still missing: $($skipped -join ', ')"
    Write-DiverWarn 'ecosystem installers that need them will report their own errors'
} else {
    Write-DiverOk 'all toolchains present'
}
