# steps-ps/60-formatters.ps1 — install formatter binaries on native Windows.
#
# Data-driven mirror of steps/60-formatters.sh. Skips when the binary is on
# PATH; installs user-locally otherwise. Managed binaries are recorded in
# the step manifest for 99-finish verification.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
. (Join-Path $LibDir 'toolchain.ps1')
Initialize-DiverPlatform

if ($env:DIVER_INSTALL_FORMATTERS -eq '0') {
    Write-DiverLog 'skipping formatters (DIVER_INSTALL_FORMATTERS=0)'
    exit 0
}

# ------------------------------------------------------------ uv tools ---
# pkg, bin
$uvTools = @(
    @('autopep8'), @('bean-format', 'beancount'), @('black'), @('cmake-format'),
    @('djlint'), @('docstrfmt'), @('fprettify'), @('gdformat'), @('gersemi'),
    @('mdformat'), @('robotframework-tidy', 'robotidy'), @('ruff'), @('snakefmt'),
    @('sqlfluff'), @('xmlformat'), @('yapf')
)
foreach ($t in $uvTools) {
    if ($t.Count -gt 1) { Install-DiverUvTool $t[0] $t[1] } else { Install-DiverUvTool $t[0] }
}

# ------------------------------------------------------------------ npm ---
$npmPkgs = @(
    @('bibtex-tidy'), @('bs-platform', 'refmt'), @('elm-format'),
    @('js-beautify', 'css-beautify'), @('prettier'), @('@fsouza/prettierd', 'prettierd'),
    @('purs-tidy'), @('rescript'), @('sql-formatter')
)
foreach ($t in $npmPkgs) {
    if ($t.Count -gt 1) { Install-DiverNpmGlobal $t[0] $t[1] } else { Install-DiverNpmGlobal $t[0] }
}

# ---------------------------------------------------------------- cargo ---
foreach ($t in @(@('fnlfmt'), @('just'), @('shellharden'), @('stylua'), @('tex-fmt'), @('tombi'), @('typstfmt'), @('typstyle'))) {
    if ($t.Count -gt 1) { Install-DiverCargoPackage $t[0] $t[1] } else { Install-DiverCargoPackage $t[0] }
}

# ------------------------------------------------------------------- go ---
$goPkgs = @(
    @('cuelang.org/go/cmd/cue@latest', 'cue'),
    @('github.com/a-h/templ/cmd/templ@latest', 'templ'),
    @('github.com/google/go-jsonnet/cmd/jsonnetfmt@latest', 'jsonnetfmt'),
    @('github.com/google/yamlfmt/cmd/yamlfmt@latest', 'yamlfmt'),
    @('golang.org/x/tools/cmd/goimports@latest', 'goimports'),
    @('mvdan.cc/gofumpt@latest', 'gofumpt'),
    @('mvdan.cc/sh/v3/cmd/shfmt@latest', 'shfmt')
)
foreach ($t in $goPkgs) { Install-DiverGoPackage $t[0] $t[1] }

# ---------------------------------------------------------------- dotnet ---
# (dotnet tools handled below — kept separate for clarity)
if (Test-DiverCommand 'dotnet') {
    foreach ($pkg in @('csharpier', 'fantomas')) {
        if (-not (Test-DiverCommand $pkg)) {
            Write-DiverLog "installing $pkg (dotnet tool)"
            try { & dotnet tool install -g $pkg 2>$null | Out-Null; Write-DiverOk "$pkg (dotnet tool)" }
            catch { Write-DiverWarn "$pkg failed (continuing)" }
        }
        Add-DiverManifest $pkg
    }
} else {
    Write-DiverWarn 'skipping dotnet formatters: dotnet not on PATH'
    Add-DiverManifest 'csharpier'; Add-DiverManifest 'fantomas'
}

# ----------------------------------------------------------- gh releases ---
# repo, bin, asset-regex (windows)
$ghReleases = @(
    @('kamadorueda/alejandra', 'alejandra', 'x86_64-pc-windows-msvc'),
    @('Azure/bicep', 'bicep', 'bicep-win-x64'),
    @('biomejs/biome', 'biome', 'biome-win32-x64'),
    @('bufbuild/buf', 'buf', 'buf-Windows-x86_64'),
    @('bazelbuild/buildtools', 'buildifier', 'buildifier-windows-amd64'),
    @('terrastruct/d2', 'd2', 'd2-.*-windows-amd64\.tar\.gz'),
    @('dprint/dprint', 'dprint', 'dprint-x86_64-pc-windows-msvc\.zip'),
    @('gleam-lang/gleam', 'gleam', 'gleam-.*-x86_64-pc-windows-msvc\.zip'),
    @('hashicorp/nomad', 'nomad', 'nomad_.*_windows_amd64\.zip'),
    @('hashicorp/packer', 'packer', 'packer_.*_windows_amd64\.zip'),
    @('hashicorp/terraform', 'terraform', 'terraform_.*_windows_amd64\.zip'),
    @('opentofu/opentofu', 'tofu', 'tofu_.*_windows_amd64\.zip'),
    @('open-policy-agent/opa', 'opa', 'opa_windows_amd64'),
    @('jqlang/jq', 'jq', 'jq-windows-amd64'),
    @('pinterest/ktlint', 'ktlint', 'ktlint.*\.zip'),
    @('kcl-lang/kcl', 'kcl', 'kcl-.*-windows\.zip'),
    @('ziglang/zig', 'zig', 'zig-windows-x86_64-.*\.zip'),
    @('JohnnyMorganz/StyLua', 'stylua', 'stylua-windows-x86_64\.zip'),
    @('chipsalliance/verible', 'verible-verilog-format', 'verible-.*win64.*\.zip')
)
foreach ($t in $ghReleases) { Install-DiverGhRelease $t[0] $t[1] $t[2] }

# ------------------------------------------------------------------ misc ---

# zprint: java uberjar.
if (-not (Test-DiverCommand 'zprint')) {
    $zprintUrl = Get-DiverGhAssetUrl 'kkinnear/zprint' 'zprint-filter.*\.jar'
    if ($zprintUrl) { Install-DiverJavaJar $zprintUrl 'zprint' }
    else { Write-DiverWarn 'zprint: no uberjar asset in latest release' }
}
Add-DiverManifest 'zprint'

if (-not (Test-DiverCommand 'swift-format')) {
    Write-DiverWarn 'swift-format: install the Swift toolchain (swiftly) — skipped'
}
Add-DiverManifest 'swift-format'

Write-DiverOk 'formatters step done'
