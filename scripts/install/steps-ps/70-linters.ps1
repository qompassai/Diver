# steps-ps/70-linters.ps1 — install linter binaries on native Windows.
#
# Data-driven mirror of steps/70-linters.sh. Managed binaries are recorded
# in the step manifest for 99-finish verification.

$LibDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'lib-ps'
. (Join-Path $LibDir 'common.ps1')
. (Join-Path $LibDir 'toolchain.ps1')
Initialize-DiverPlatform

if ($env:DIVER_INSTALL_LINTERS -eq '0') {
    Write-DiverLog 'skipping linters (DIVER_INSTALL_LINTERS=0)'
    exit 0
}

# ------------------------------------------------------------ uv tools ---
$uvTools = @(
    @('ansible-lint'), @('bashate'), @('cfn-lint'), @('cmakelint'), @('codespell'),
    @('cython-lint'), @('detect-secrets', 'detect-secrets-hook'), @('djlint'),
    @('flake8'), @('flawfinder'), @('fortitude'), @('mypy', 'dmypy'),
    @('oelint-adv'), @('proselint'), @('pycodestyle'), @('pylint'), @('pyrefly'),
    @('rpmlint'), @('rstcheck'), @('ruff'), @('snakefmt'), @('snakemake'),
    @('sphinx-lint'), @('sqlfluff'), @('ty'), @('vhdl-style-guide', 'vsg'),
    @('vim-vint', 'vint'), @('yamllint')
)
foreach ($t in $uvTools) {
    if ($t.Count -gt 1) { Install-DiverUvTool $t[0] $t[1] } else { Install-DiverUvTool $t[0] }
}

# ------------------------------------------------------------------ npm ---
$npmPkgs = @(
    @('@chris48s/v8r', 'v8r'), @('@commitlint/cli', 'commitlint'),
    @('@neondatabase/eugene', 'eugene'), @('@redocly/cli', 'redocly'),
    @('@stoplight/spectral-cli', 'spectral'), @('alex'), @('bootlint'),
    @('cspell'), @('csslint'), @('eslint'), @('eslint_d'), @('html-validate'),
    @('htmlhint'), @('markdownlint-cli', 'markdownlint'), @('markdownlint-cli2'),
    @('markuplint'), @('oxlint'), @('quick-lint-js'), @('remark-cli', 'remark'),
    @('solhint'), @('textlint'), @('write-good')
)
foreach ($t in $npmPkgs) {
    if ($t.Count -gt 1) { Install-DiverNpmGlobal $t[0] $t[1] } else { Install-DiverNpmGlobal $t[0] }
}

# ---------------------------------------------------------------- cargo ---
$crates = @(
    @('ast-grep'), @('dotenv-linter'), @('mado'), @('naga-cli', 'naga'),
    @('selene'), @('sqruff'), @('typos-cli', 'typos'), @('zizmor')
)
foreach ($t in $crates) {
    if ($t.Count -gt 1) { Install-DiverCargoPackage $t[0] $t[1] } else { Install-DiverCargoPackage $t[0] }
}

# ------------------------------------------------------------------- go ---
$goPkgs = @(
    @('github.com/candid82/joker@latest', 'joker'),
    @('github.com/daveshanley/vacuum@latest', 'vacuum'),
    @('github.com/mgechev/revive@latest', 'revive'),
    @('github.com/mrtazz/checkmake@latest', 'checkmake'),
    @('github.com/yoheimuta/protolint@latest', 'protolint'),
    @('honnef.co/go/tools/cmd/staticcheck@latest', 'staticcheck')
)
foreach ($t in $goPkgs) { Install-DiverGoPackage $t[0] $t[1] }

# ----------------------------------------------------------- gh releases ---
$ghReleases = @(
    @('clj-kondo/clj-kondo', 'clj-kondo', 'clj-kondo-.*-windows-amd64\.zip'),
    @('errata-ai/vale', 'vale', 'vale_.*_Windows_64-bit\.tar\.gz'),
    @('hadolint/hadolint', 'hadolint', 'hadolint-Windows-x86_64'),
    @('koalaman/shellcheck', 'shellcheck', 'shellcheck-.*\.zip'),
    @('rhysd/actionlint', 'actionlint', 'actionlint_.*_windows_amd64\.tar\.gz'),
    @('StyraInc/regal', 'regal', 'regal_.*_Windows_x86_64\.tar\.gz'),
    @('terraform-linters/tflint', 'tflint', 'tflint_.*_windows_amd64\.zip'),
    @('woodruffw/zizmor', 'zizmor', 'zizmor-.*windows.*\.zip')
)
foreach ($t in $ghReleases) { Install-DiverGhRelease $t[0] $t[1] $t[2] }

# ------------------------------------------------------------------ jars ---
# checkstyle: java -jar.
$checkstyleUrl = Get-DiverGhAssetUrl 'checkstyle/checkstyle' 'checkstyle-.*-all\.jar'
if ($checkstyleUrl) { Install-DiverJavaJar $checkstyleUrl 'checkstyle' }
else { Write-DiverWarn 'checkstyle: no -all.jar asset in latest release' }

# pmd: JVM zip, link bin\pmd.
if (-not (Test-DiverCommand 'pmd')) {
    $pmdUrl = Get-DiverGhAssetUrl 'pmd/pmd' 'pmd-dist-.*-bin\.zip'
    if ($pmdUrl) {
        $pmdDest = Join-Path $DiverPrefix 'gh\pmd-dist'
        $out = Join-Path $DiverTempDir 'pmd.zip'
        try {
            Write-DiverLog 'installing pmd'
            Invoke-DiverDownload $pmdUrl $out
            Expand-DiverArchive $out $pmdDest
            $inner = Get-ChildItem -LiteralPath $pmdDest -Recurse -File -Filter 'pmd.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($inner) {
                $shim = Join-Path $DiverBin 'pmd.cmd'
                "@echo off`r`ncall `"$($inner.FullName)`" %*" | Set-Content -LiteralPath $shim -Encoding Ascii
                Write-DiverOk 'pmd → pmd.cmd'
            } else { Write-DiverWarn 'pmd extracted but pmd.bat not found' }
        } catch { Write-DiverWarn "pmd failed: $_" }
    } else { Write-DiverWarn 'pmd: no bin.zip asset in latest release' }
}
Add-DiverManifest 'pmd'

# golangci-lint: official binary (winget user scope or GH).
if (-not (Test-DiverCommand 'golangci-lint')) {
    if (-not (Install-DiverWingetPackage 'golangci.golangci-lint' 'golangci-lint')) {
        Install-DiverGhRelease 'golangci/golangci-lint' 'golangci-lint' 'golangci-lint-.*-windows-amd64\.tar\.gz'
    }
} else { Add-DiverManifest 'golangci-lint' }

# trivy: official installer into user scope.
if (-not (Test-DiverCommand 'trivy')) {
    if (-not (Install-DiverWingetPackage 'AquaSecurity.Trivy' 'trivy')) {
        Install-DiverGhRelease 'aquasecurity/trivy' 'trivy' 'trivy_.*_windows-64bit\.tar\.gz'
    }
} else { Add-DiverManifest 'trivy' }

Write-DiverOk 'linters step done'
