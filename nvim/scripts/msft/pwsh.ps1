# Qompass AI Diver - Neovim Windows Bootstrap Script
# Rootless PowerShell Installer
# Copyright (C) 2025 Qompass AI, All rights reserved
# ============================================================
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#.\pwsh.ps1
$ErrorActionPreference = 'Stop'
$REPO_URL = "https://github.com/qompassai/Diver.git"
$CONFIG_DIR = "$env:LOCALAPPDATA\nvim"
$DATA_DIR = "$env:LOCALAPPDATA\nvim-data"
$PACK_DIR = "$DATA_DIR\pack"
function Write-Info { Write-Host "INFO: $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "SUCCESS: $args" -ForegroundColor Green }
function Write-Error { Write-Host "ERROR: $args" -ForegroundColor Red }
function Write-Warn { Write-Host "WARN: $args" -ForegroundColor Yellow }
function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}
function Install-DiverConfig {
    Write-Info "Starting Qompass AI Diver Neovim installation..."
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher is required. Current version: $($PSVersionTable.PSVersion)"
        exit 1
    }
    if (-not (Test-Command nvim)) {
        Write-Warn "Neovim not found. Please install Neovim first:"
        Write-Info "Option 1 (winget): winget install Neovim.Neovim"
        Write-Info "Option 2 (scoop): scoop install neovim"
        Write-Info "Option 3 (choco): choco install neovim"
        exit 1
    }
    $nvimVersion = (nvim --version | Select-Object -First 1) -replace 'NVIM v', ''
    Write-Info "Found Neovim version: $nvimVersion"
    if ([version]$nvimVersion -lt [version]"0.12.0") {
        Write-Warn "Neovim 0.12+ recommended. You have $nvimVersion"
    }
    Write-Info "Checking dependencies..."
    $missingDeps = @()
    @('git', 'rg', 'fd') | ForEach-Object {
        if (-not (Test-Command $_)) {
            $missingDeps += $_
        }
    }
    if ($missingDeps.Count -gt 0) {
        Write-Warn "Missing recommended dependencies: $($missingDeps -join ', ')"
        Write-Info "Install with: winget install Git.Git BurntSushi.ripgrep.MSVC sharkdp.fd"
    }
    if (Test-Path $CONFIG_DIR) {
        $backupDir = "$CONFIG_DIR.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Warn "Existing config found. Backing up to: $backupDir"
        Move-Item -Path $CONFIG_DIR -Destination $backupDir -Force
    }
    Write-Info "Creating directory structure..."
    @($CONFIG_DIR, $DATA_DIR, $PACK_DIR) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Success "Created: $_"
        }
    }
    Write-Info "Setting up Diver config..."
    if (Test-Command git) {
        Write-Info "Cloning from $REPO_URL..."
        try {
            git clone --depth 1 $REPO_URL "$CONFIG_DIR.tmp"
            Get-ChildItem "$CONFIG_DIR.tmp" -Exclude '.git' |
                Move-Item -Destination $CONFIG_DIR -Force

            Remove-Item "$CONFIG_DIR.tmp" -Recurse -Force
            Write-Success "Config cloned successfully"
        }
        catch {
            Write-Error "Failed to clone repository: $_"
            Write-Info "You can manually copy your config to: $CONFIG_DIR"
            exit 1
        }
    }
    else {
        Write-Warn "Git not found. Please manually copy your config to: $CONFIG_DIR"
        Write-Info "Then re-run this script or run Neovim directly."
        exit 1
    }
    Write-Info "Setting up vim.pack structure..."
    $packDirs = @(
        "$PACK_DIR\qompass\start",
        "$PACK_DIR\qompass\opt"
    )
    $packDirs | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    Write-Success "vim.pack directories created"
    Write-Info "Setting up environment variables..."
    $userEnv = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $nvimPath = Split-Path (Get-Command nvim).Path
    if ($userEnv -notlike "*$nvimPath*") {
        Write-Info "Adding Neovim to user PATH..."
        [System.Environment]::SetEnvironmentVariable(
            'Path',
            "$userEnv;$nvimPath",
            'User'
        )
    }
    $updateScript = @'
# Plugin update helper script
Write-Host "Updating Neovim plugins..." -ForegroundColor Cyan
nvim --headless +"lua vim.pack.update(nil, {confirm = true})" +qa
Write-Host "Plugin update complete!" -ForegroundColor Green
'@
    $updateScriptPath = "$CONFIG_DIR\update-plugins.ps1"
    Set-Content -Path $updateScriptPath -Value $updateScript
    Write-Success "Created plugin update helper: $updateScriptPath"
    Write-Info "Installing plugins..."
    Write-Info "This may take a few minutes on first run..."
    try {
        $nvimOutput = nvim --headless +"lua vim.defer_fn(function() vim.cmd('qa') end, 5000)" 2>&1
        Start-Sleep -Seconds 2
        Write-Success "Initial Neovim setup complete"
    }
    catch {
        Write-Warn "Headless initialization had issues"
        Write-Info "Plugins will be installed on first Neovim launch"
    }

    Write-Success "`nGreat Success!"
    Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "`n=== Configuration Locations ===" -ForegroundColor Cyan
    Write-Host "Config:  $CONFIG_DIR"
    Write-Host "Data:    $DATA_DIR"
    Write-Host "Plugins: $PACK_DIR"

    Write-Host "`nWould you like to launch Neovim now? (y/N): " -NoNewline
    $response = Read-Host
    if ($response -eq 'y' -or $response -eq 'Y') {
        nvim
    }
}
try {
    Install-DiverConfig
}
catch {
    Write-Error "Installation failed: $_"
    Write-Info "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
