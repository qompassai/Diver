#!/usr/bin/env bash
# steps/70-linters.sh — install linter binaries, rootlessly.
#
# Same data-driven shape as 60-formatters.sh. Single-file scripts that
# upstream only publishes as source (checkpatch.pl, apkbuild-lint) are
# curled straight into $BIN_DIR. Binaries with no clean rootless path are
# NOT attempted here — 99-finish reports them from DIVER_UNSUPPORTED.
#
# Env:
#   DIVER_INSTALL_LINTERS  0 to skip (default 1)

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=../lib/toolchain.sh
source "$LIB_DIR/toolchain.sh"
diver_detect_platform

if [[ ${DIVER_INSTALL_LINTERS:-1} != 1 ]]; then
  diver_log "skipping linters (DIVER_INSTALL_LINTERS=0)"
  exit 0
fi

# ------------------------------------------------------- platform lanes ---

if ((IS_NIX_ON_DROID)); then
  for pkg in actionlint hadolint ruff shellcheck statix vale yamllint; do
    if ! diver_have "$pkg"; then
      diver_nix_install "nixpkgs#$pkg" || true
    fi
    diver_manifest_add "$pkg"
  done
  diver_ok "linters step done (nix lane)"
  exit 0
fi

if ((IS_TERMUX)); then
  for pkg in ruff shellcheck; do
    if ! diver_have "$pkg"; then
      pkg install -y "$pkg" >/dev/null 2>&1 || diver_warn "termux: pkg install $pkg failed"
    fi
    diver_manifest_add "$pkg"
  done
fi

# ------------------------------------------------------------ uv tools ---

while read -r pkg bin; do
  [[ -z $pkg || $pkg == \#* ]] && continue
  diver_uv_tool "$pkg" "${bin:-$pkg}"
done <<'EOF'
ansible-lint
bashate
cfn-lint
cmakelint
codespell
cython-lint
detect-secrets detect-secrets-hook
djlint
flake8
flawfinder
fortitude
mypy dmypy
oelint-adv
proselint
pycodestyle
pylint
pyrefly
rpmlint
rstcheck
ruff
snakefmt
snakemake
sphinx-lint
sqlfluff
ty
vhdl-style-guide vsg
vim-vint vint
yamllint
EOF

# ------------------------------------------------------------------ npm ---

while read -r pkg bin; do
  [[ -z $pkg || $pkg == \#* ]] && continue
  diver_npm_global "$pkg" "${bin:-$pkg}"
done <<'EOF'
@chris48s/v8r v8r
@commitlint/cli commitlint
@neondatabase/eugene eugene
@redocly/cli redocly
@stoplight/spectral-cli spectral
alex
bootlint
cspell
csslint
eslint
eslint_d
html-validate
htmlhint
markdownlint-cli markdownlint
markdownlint-cli2
markuplint
oxlint
quick-lint-js
remark-cli remark
solhint
textlint
write-good
EOF

# ---------------------------------------------------------------- cargo ---

while read -r crate bin; do
  [[ -z $crate || $crate == \#* ]] && continue
  diver_cargo_pkg "$crate" "${bin:-$crate}"
done <<'EOF'
ast-grep ast-grep
dotenv-linter
mado
naga-cli naga
selene
sqruff
typos-cli typos
zizmor
EOF

# ------------------------------------------------------------------- go ---

while read -r module bin; do
  [[ -z $module || $module == \#* ]] && continue
  diver_go_pkg "$module" "${bin:-$module}"
done <<'EOF'
github.com/candid82/joker@latest joker
github.com/daveshanley/vacuum@latest vacuum
github.com/mgechev/revive@latest revive
github.com/mrtazz/checkmake@latest checkmake
github.com/yoheimuta/protolint@latest protolint
honnef.co/go/tools/cmd/staticcheck@latest staticcheck
EOF

# ------------------------------------------------------------------ gem ---

diver_gem_pkg herb herb-lint
diver_gem_pkg mdl
diver_gem_pkg rubocop

# ----------------------------------------------------------------- cpan ---

diver_cpan_pkg Perl::Critic perlcritic

# -------------------------------------------------------------- luarocks ---

diver_luarocks_pkg luacheck

# ----------------------------------------------------------- gh releases ---

while IFS='|' read -r repo bin regex; do
  [[ -z $repo || $repo == \#* ]] && continue
  diver_gh_release "$repo" "$bin" "$regex"
done <<'EOF'
clj-kondo/clj-kondo|clj-kondo|clj-kondo-.*-linux-amd64\.zip
danmar/cppcheck|cppcheck|cppcheck-.*linux.*\.tar\.gz
errata-ai/vale|vale|vale_.*_Linux_64-bit\.tar\.gz
hadolint/hadolint|hadolint|hadolint-Linux-x86_64
htacg/tidy-html5|tidy|tidy-.*linux.*\.tar\.gz
koalaman/shellcheck|shellcheck|shellcheck-.*\.linux\.x86_64\.tar\.xz
MikePopoloski/slang|slang|slang-.*linux.*\.tar\.gz
nerdypepper/statix|statix|statix-.*linux.*\.tar\.gz
rhysd/actionlint|actionlint|actionlint_.*_linux_amd64\.tar\.gz
StyraInc/regal|regal|regal_.*_Linux_x86_64\.tar\.gz
terraform-linters/tflint|tflint|tflint_.*_linux_amd64\.zip
woodruffw/zizmor|zizmor|zizmor-.*linux.*\.tar\.gz
EOF

# ------------------------------------------------------------------ jars ---

# checkstyle + pmd are java -jar tools; detekt is a JVM zip.
if ! diver_have checkstyle; then
  checkstyle_url="$(_diver_gh_asset_url checkstyle/checkstyle 'checkstyle-.*-all\.jar' 2>/dev/null || true)"
  if [[ -n $checkstyle_url ]]; then
    diver_java_jar "$checkstyle_url" checkstyle
  else
    diver_warn "checkstyle: no -all.jar asset in latest release"
    diver_manifest_add checkstyle
  fi
fi
if ! diver_have pmd; then
  pmd_url="$(_diver_gh_asset_url pmd/pmd 'pmd-dist-.*-bin\.zip' 2>/dev/null || true)"
  if [[ -n $pmd_url ]]; then
    pmd_dest="$PREFIX/share/pmd"
    if [[ ! -x $pmd_dest/bin/pmd ]]; then
      diver_log "installing pmd"
      diver_download_extract "$pmd_url" "$pmd_dest" || diver_warn "pmd download failed"
      inner="$(find "$pmd_dest" -maxdepth 2 -name pmd -type f 2>/dev/null | head -1)"
      [[ -n $inner ]] && diver_link_bin "$inner" pmd
    fi
  else
    diver_warn "pmd: no bin.zip asset in latest release"
  fi
fi
diver_manifest_add pmd
if ! diver_have detekt; then
  detekt_url="$(_diver_gh_asset_url detekt/detekt 'detekt-cli-.*\.zip' 2>/dev/null || true)"
  if [[ -n $detekt_url ]]; then
    detekt_dest="$PREFIX/share/detekt"
    if [[ ! -x $detekt_dest/bin/detekt-cli ]]; then
      diver_log "installing detekt"
      diver_download_extract "$detekt_url" "$detekt_dest" || diver_warn "detekt download failed"
      inner="$(find "$detekt_dest" -name 'detekt-cli*' -type f 2>/dev/null | head -1)"
      [[ -n $inner ]] && diver_link_bin "$inner" detekt
    fi
  else
    diver_warn "detekt: no cli zip in latest release"
  fi
fi
diver_manifest_add detekt

# ------------------------------------------------------------------ phar ---

# phan needs the php runtime.
diver_phar "https://github.com/phan/phan/releases/latest/download/phan.phar" phan

# ------------------------------------------------------- install scripts ---

# golangci-lint: upstream install script, pinned version, into $BIN_DIR.
if ! diver_have golangci-lint; then
  gl_ver="v2.5.0"
  diver_log "installing golangci-lint $gl_ver"
  if curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b "$BIN_DIR" "$gl_ver" >/dev/null 2>&1; then
    diver_ok "golangci-lint $gl_ver"
  else
    diver_warn "golangci-lint install script failed"
  fi
fi
diver_manifest_add golangci-lint

# trivy: upstream install script into $BIN_DIR.
if ! diver_have trivy; then
  diver_log "installing trivy"
  if curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b "$BIN_DIR" >/dev/null 2>&1; then
    diver_ok "trivy"
  else
    diver_warn "trivy install script failed"
  fi
fi
diver_manifest_add trivy

# ------------------------------------------------------- single-file ones ---

# checkpatch.pl: the kernel's checker is only published as a script.
diver_curl_script \
  "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/checkpatch.pl" \
  checkpatch.pl

# apkbuild-lint: Alpine's linter is only published as a script in aports.
diver_curl_script \
  "https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/scripts/apkbuild-lint" \
  apkbuild-lint

# ------------------------------------------------------------------ misc ---

# janet: source build (janet-lang/janet).
diver_source_make "https://github.com/janet-lang/janet.git" janet

# TeX Live linters (chktex, lacheck, bibclean): only when tlmgr exists.
if diver_have tlmgr; then
  diver_log "installing TeX Live linters (user tree)"
  tlmgr init-usertree >/dev/null 2>&1 || true
  tlmgr install chktex lacheck bibtex8 >/dev/null 2>&1 \
    && diver_ok "tex linters" || diver_warn "tlmgr install failed"
else
  diver_warn "chktex/lacheck/bibclean: need TeX Live user install (install-tl --no-interaction to ~/texlive) — skipped"
fi
for b in chktex lacheck bibclean; do diver_manifest_add "$b"; done

# Shells with no clean rootless package — honest skip, not a silent miss.
for b in fish zsh ksh; do
  if ! diver_have "$b"; then
    diver_warn "$b: no clean rootless package (source build possible) — skipped"
  fi
  diver_manifest_add "$b"
done

diver_ok "linters step done"
