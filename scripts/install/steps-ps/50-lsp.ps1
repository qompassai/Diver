# steps-ps/50-lsp.ps1 — install language servers on native Windows.
#
# PowerShell port of scripts/lsp/*.sh. Package lists are kept in sync with:
#   lsp/go.sh, lsp/cargo.sh, lsp/js.sh, lsp/py.sh, lsp/ruby.sh,
#   lsp/vs.sh, lsp/motoko.sh
# (keep the two in sync when either changes)
#
# Source-build installers (idris2, pascal, clir_ls, ocaml/opam, mojo/pixi,
# jimmer/gradle, tilt) are WSL-only — run scripts/install.sh inside WSL.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
Initialize-DiverPlatform

$Strict = ($env:DIVER_LSP_STRICT -eq '1')
$Failed = @()

function Invoke-DiverToolInstall {
    param([string]$Label, [scriptblock]$Install)
    Write-DiverLog "installing $Label"
    try {
        & $Install | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }
        return $true
    } catch {
        Write-DiverWarn "failed: $Label — $_"
        $script:Failed += $Label
        if ($Strict) { throw "stopping (DIVER_LSP_STRICT=1) at $Label" }
        return $false
    }
}

# ------------------------------------------------------------------ go ---
if (Test-DiverCommand 'go.exe') {
    # Sync with lsp/go.sh `tools=(...)`.
    $goTools = @(
        'github.com/a-h/templ/cmd/templ@latest',
        'github.com/anz-bank/sysl/cmd/sysl@latest',
        'github.com/arduino/arduino-language-server@latest',
        'github.com/bufbuild/buf/cmd/buf@latest',
        'github.com/docker/docker-language-server/cmd/docker-language-server@latest',
        'github.com/go-delve/delve/cmd/dlv@latest',
        'github.com/golangci/golangci-lint/cmd/golangci-lint@latest',
        'github.com/grafana/jsonnet-language-server@latest',
        'github.com/hashicorp/terraform-ls@latest',
        'github.com/huderlem/poryscript-pls@latest',
        'github.com/hyprland-community/hyprls/cmd/hyprls@latest',
        'github.com/juliosueiras/nomad-lsp@latest',
        'github.com/kitagry/bqls@latest',
        'github.com/kitagry/regols@latest',
        'github.com/laravel-ls/laravel-ls/cmd/laravel-ls@latest',
        'github.com/lotusirous/gostdsym/stdsym@latest',
        'github.com/nametake/golangci-lint-langserver@latest',
        'github.com/nobl9/nobl9-language-server/cmd/nobl9-language-server@latest',
        'github.com/nokia/ntt@latest',
        'github.com/Open-MBEE/OpenSysML/cmd/sysml-lsp@latest',
        'github.com/opa-oz/pug-lsp@latest',
        'github.com/opentofu/tofu-ls@latest',
        'github.com/ptdewey/plantuml-lsp@latest',
        'github.com/segmentio/golines@latest',
        'github.com/sqls-server/sqls@latest',
        'github.com/wader/jq-lsp@latest',
        'golang.org/dl/gotip@latest',
        'golang.org/x/tools/cmd/deadcode@latest',
        'golang.org/x/tools/cmd/godoc@latest',
        'golang.org/x/tools/gopls@latest',
        'gotest.tools/gotestsum@latest',
        'mvdan.cc/gofumpt@latest'
    )
    $env:GOBIN = $DiverBin
    $env:Path = "$DiverBin;$env:Path"
    foreach ($tool in $goTools) {
        Invoke-DiverToolInstall "go $tool" { & go.exe install $tool }
    }
} else {
    Write-DiverWarn 'go toolchain missing — skipping go language servers'
}

# ---------------------------------------------------------------- cargo ---
if (Test-DiverCommand 'cargo.exe') {
    $env:PATH = "$env:USERPROFILE\.cargo\bin;$env:Path"
    # Sync with lsp/cargo.sh `install_git ...` lines: label, repo, bin, extra args.
    $cargoTools = @(
        @('lelwel',               'https://github.com/0x2a-42/lelwel',                 'lelwel',               '--features', 'clap,cli,lsp,wasm'),
        @('mm0-rs',               'https://github.com/digama0/mm0',                    'mm0-rs',               '--locked'),
        @('vale-ls',              'https://github.com/errata-ai/vale-ls',              'vale-ls'),
        @('gn-language-server',   'https://github.com/google/gn-language-server',      'gn-language-server'),
        @('dts-lsp',              'https://github.com/igor-prusov/dts-lsp',             'dts-lsp'),
        @('ink-analyzer',         'https://github.com/ink-analyzer/ink-analyzer.git',  'ink-analyzer'),
        @('prosemd-lsp',          'https://github.com/kitten/prosemd-lsp',              'prosemd-lsp'),
        @('testing-ls-adapter',   'https://github.com/kbwo/testing-language-server',  'testing-ls-adapter'),
        @('testing-language-server','https://github.com/kbwo/testing-language-server', 'testing-language-server'),
        @('neocmakelsp',          'https://github.com/neocmakelsp/neocmakelsp',         'neocmakelsp'),
        @('pest-language-server', 'https://github.com/pest-parser/pest-ide-tools',     'pest-language-server'),
        @('rumdl',                'https://github.com/rvben/rumdl',                    'rumdl'),
        @('taplo-cli',            'https://github.com/tamasfe/taplo',                  'taplo-cli', '--features', 'lsp'),
        @('test-gen',             'https://github.com/tamasfe/taplo',                  'test-gen'),
        @('typos-lsp',            'https://github.com/tekumara/typos-lsp',              'typos-lsp'),
        @('uiua',                 'https://github.com/uiua-lang/uiua',                 'uiua', '-F', 'full'),
        @('wgsl-analyzer',        'https://github.com/wgsl-analyzer/wgsl-analyzer',    'wgsl-analyzer'),
        @('pbls',                 'https://git.sr.ht/~rrc/pbls',                       'pbls')
    )
    foreach ($t in $cargoTools) {
        $label, $repo, $bin = $t[0], $t[1], $t[2]
        $extra = @()
        if ($t.Count -gt 3) { $extra = $t[3..($t.Count - 1)] }
        Invoke-DiverToolInstall "cargo $label" { & cargo.exe install --git $repo $bin @extra }
    }
    # buck2 needs a pinned nightly toolchain (mirrors lsp/cargo.sh).
    if (Test-DiverCommand 'rustup.exe') {
        Invoke-DiverToolInstall 'buck2 (nightly toolchain)' {
            & rustup.exe toolchain install nightly-2025-08-01 | Out-Null
            & cargo.exe +nightly-2025-08-01 install --git https://github.com/facebook/buck2.git buck2
        }
    }
} else {
    Write-DiverWarn 'cargo missing — skipping cargo language servers'
}

# ------------------------------------------------------------------- js ---
if (Test-DiverCommand 'pnpm') {
    # Sync with lsp/js.sh `pnpm add -g` list.
    $jsTools = @(
        'abaplint/cli@latest', 'abaplint/transpiler-cli@latest', 'abaplint/transpiler@latest',
        'abaplint/runtime@latest', 'actions/languageserver@latest', 'angular/language-server@latest',
        'azure-pipelines-language-server@latest', 'awk-language-server@latest',
        'css-variables-language-server@latest', 'cssmodules-language-server@latest',
        'cucumber/language-server@latest', 'custom-elements-languageserver@latest',
        'dockerfile-language-server-nodejs@latest', 'dot-language-server@latest',
        'gh-actions-language-server@latest',
        'git+https://github.com/salesforce-misc/bazelrc-lsp.git',
        'herb-tools/language-server@latest', 'imc-trading/svlangserver@latest',
        'lean-language-server@latest', 'lua-3p-language-servers@latest',
        'microsoft/compose-language-service@latest', 'neo4j-cypher/language-server@latest',
        'oxlint@latest', 'perlnavigator-server@latest', 'quick-lint-js@latest',
        'rokucommunity/bslint@latest', 'rescript/language-server@latest', 'sap/cds-lsp@latest',
        'sf-agentscript/lsp-server@latest', 'sf-agentscript/agentforce-dialect@latest',
        'sf-agentscript/agentscript-dialect@latest', 'sf-agentscript/language@latest',
        'sf-agentscript/parser-tree-sitter@latest', 'sf-agentscript/types@latest',
        'shopify/theme-check-common@latest', 'shopify/liquid-html-parser@latest',
        'shopify/theme-check-browser@latest', 'shopify/theme-check-node@latest',
        'shopify/theme-graph@latest', 'shopify/prettier-plugin-liquid@latest',
        'shopify/codemirror-language-client@latest', 'shopify/theme-language-server-node@latest',
        'shopify/theme-language-server-browser@latest', 'shopify/cli@latest',
        'solc@latest', 'solidity-ls@latest', 'stimulus-language-server@latest',
        'stylable/language-service@latest', 'stylelint-lsp@latest', 'svelte-language-server@latest',
        'tailwindcss/language-server@latest', 'turbo-language-server@latest',
        'typescript-language-server@latest', 'typescript@latest', 'typespec/compiler@latest',
        'urbit/hoon-language-server@latest', 'vim-language-server@latest', 'vlabo/cspell-lsp@latest',
        'vscode-langservers-extracted@latest', 'vue/language-server@latest', 'yaml-language-server@latest'
    )
    Invoke-DiverToolInstall 'pnpm global language servers' { & pnpm add -g @jsTools }
} else {
    Write-DiverWarn 'pnpm missing — skipping node language servers'
}

# ------------------------------------------------------------------- py ---
# uv-managed interpreters refuse `uv pip install --system` by design, so use
# `uv tool install` (per-package venvs) and mirror the shims into $DiverBin.
if (Test-DiverCommand 'uv.exe') {
    foreach ($pkg in @('zuban', 'lark-parser-language-server', 'jedi-language-server')) {
        Install-DiverUvTool $pkg
    }
} elseif (Test-DiverCommand 'pip') {
    Invoke-DiverToolInstall 'pip language servers' {
        & pip install --user zuban lark-parser-language-server jedi-language-server
    }
} else {
    Write-DiverWarn 'no pip/uv — skipping python language servers'
}

# ----------------------------------------------------------------- ruby ---
if (Test-DiverCommand 'gem') {
    Invoke-DiverToolInstall 'gem language servers' {
        & gem install --user-install steep standard ruby-lsp sorbet sorbet-runtime rubocop syntax_tree solargraph
    }
} else {
    Write-DiverWarn 'gem missing — skipping ruby language servers'
}

# ------------------------------------------------------------- vsix ones ---
function Install-VsixServer {
    param([string]$Name, [string]$Url, [string]$BinRelPath, [string]$ShimName)
    $dest = Join-Path $DiverDataDir $Name
    $out  = Join-Path $DiverTempDir "$Name.vsix"
    try {
        Write-DiverLog "installing $Name (VSIX)"
        Invoke-DiverDownload $Url $out
        if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
        Expand-DiverArchive $out $dest
        $target = Join-Path $dest $BinRelPath
        if (-not (Test-Path -LiteralPath $target)) {
            Write-DiverWarn "$Name extracted but $BinRelPath not found — inspect $dest"
            return
        }
        # Shim: .cmd that execs the server (node script or jar).
        $shim = Join-Path $DiverBin "$ShimName.cmd"
        if ($target -match '\.jar$') {
            "@echo off`r`njava -jar `"$target`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
        } else {
            "@echo off`r`nnode `"$target`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
        }
        Write-DiverOk "$Name → $ShimName"
    } catch {
        Write-DiverWarn "$Name VSIX install failed: $_"
        $script:Failed += $Name
    }
}

# Sync with lsp/vs.sh (openedge-abl) and lsp/motoko.sh.
Install-VsixServer 'openedge-abl-lsp' `
    'https://RiversideSoftware.gallery.vsassets.io/_apis/public/gallery/publisher/RiversideSoftware/extension/openedge-abl-lsp/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage' `
    'resources\abl-lsp.jar' 'openedge-abl-ls'
Install-VsixServer 'motoko' `
    'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/dfinity-foundation/vsextensions/vscode-motoko/0.18.7/vspackage' `
    'server\out\server.js' 'motoko-ls'

Write-Host ''
Write-DiverWarn 'WSL-only installers (need make/opam/ninja-from-source): idris2, pascal, clir_ls, ocaml, mojo, jimmer, tilt'
Write-DiverWarn 'Run scripts/install.sh inside WSL for those.'

if ($Failed.Count -gt 0) {
    Write-DiverWarn "$($Failed.Count) installer(s) failed: $($Failed -join ', ')"
} else {
    Write-DiverOk 'all LSP installers completed'
}
