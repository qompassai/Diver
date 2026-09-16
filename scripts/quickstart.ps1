# #################################################################
# /qompassai/scripts/quickstart.ps1
# Qompass AI Quickstart
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
# /qompassai/Diver/scripts/quickstart.ps1
# Qompass AI Diver Windows / WSL Quickstart Wrapper

[CmdletBinding()]
param(
    [switch]$NoLsps,
    [switch]$StrictLsps
)

$ErrorActionPreference = 'Stop'

$ScriptDirectory = Split-Path -Parent $PSCommandPath
$BashQuickstart = Join-Path $ScriptDirectory 'quickstart.sh'

if (-not (Test-Path -LiteralPath $BashQuickstart -PathType Leaf)) {
    throw "Bash quickstart script was not found: $BashQuickstart"
}

$Wsl = Get-Command 'wsl.exe' -ErrorAction SilentlyContinue

if ($null -eq $Wsl) {
    throw @'
WSL is required for the current Diver quickstart on Windows.

The primary installer and LSP installers are Bash/Linux scripts. Install WSL,
then run this wrapper again:

  wsl --install

After rebooting and completing your Linux distribution setup:

  powershell -ExecutionPolicy Bypass -File .\scripts\quickstart.ps1
'@
}

$WslQuickstart = (& wsl.exe wslpath -a $BashQuickstart).Trim()

if ([string]::IsNullOrWhiteSpace($WslQuickstart)) {
    throw "Unable to translate the quickstart path for WSL: $BashQuickstart"
}

$Environment = @()

if ($NoLsps) {
    $Environment += 'DIVER_INSTALL_LSPS=0'
}

if ($StrictLsps) {
    $Environment += 'DIVER_LSP_STRICT=1'
}

$EnvironmentPrefix = if ($Environment.Count -gt 0) {
    ($Environment -join ' ') + ' '
} else {
    ''
}

$Command = "${EnvironmentPrefix}bash '$WslQuickstart'"

Write-Host "→ Running Diver quickstart through WSL"
Write-Host "→ Command: $Command"

& wsl.exe -- bash -lc $Command

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
