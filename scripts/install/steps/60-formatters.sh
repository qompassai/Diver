#!/usr/bin/env bash
# steps/60-formatters.sh — install formatter binaries, rootlessly.
#
# Data-driven: every entry is "<channel> <package> [binary]" and skips when
# the binary is already on PATH. Channels with missing toolchains are
# reported, not fatal. Binaries managed here are recorded in the step
# manifest for 99-finish verification.
#
# Env:
#   DIVER_INSTALL_FORMATTERS  0 to skip (default 1)

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=../lib/toolchain.sh
source "$LIB_DIR/toolchain.sh"
diver_detect_platform

if [[ ${DIVER_INSTALL_FORMATTERS:-1} != 1 ]]; then
  diver_log "skipping formatters (DIVER_INSTALL_FORMATTERS=0)"
  exit 0
fi

# ------------------------------------------------------- platform lanes ---

if ((IS_NIX_ON_DROID)); then
  # nixpkgs attributes usually match the binary name.
  for pkg in alejandra deadnix nixfmt-rfc-style ruff stylua shfmt shellcheck; do
    if ! diver_have "$pkg"; then
      diver_nix_install "nixpkgs#$pkg" || true
    fi
    diver_manifest_add "$pkg"
  done
  diver_ok "formatters step done (nix lane)"
  exit 0
fi

if ((IS_TERMUX)); then
  # Termux pkg names match the binaries for the common ones; tolerate misses.
  for pkg in black ruff shfmt stylua; do
    if ! diver_have "$pkg"; then
      pkg install -y "$pkg" >/dev/null 2>&1 || diver_warn "termux: pkg install $pkg failed"
    fi
    diver_manifest_add "$pkg"
  done
  # ...then fall through to the channel installs below for the rest.
fi

# ------------------------------------------------------------ uv tools ---

# pkg [bin]
while read -r pkg bin; do
  [[ -z $pkg || $pkg == \#* ]] && continue
  diver_uv_tool "$pkg" "${bin:-$pkg}"
done <<'EOF'
autopep8
bean-format beancount
black
cmake-format
djlint
docstrfmt
fprettify
gdformat
gersemi
mdformat
robotframework-tidy robotidy
ruff
snakefmt
sqlfluff
xmlformat
yapf
EOF

# ------------------------------------------------------------------ npm ---

while read -r pkg bin; do
  [[ -z $pkg || $pkg == \#* ]] && continue
  diver_npm_global "$pkg" "${bin:-$pkg}"
done <<'EOF'
bibtex-tidy
bs-platform refmt
elm-format
js-beautify css-beautify
prettier
@fsouza/prettierd prettierd
purs-tidy
rescript
sql-formatter
EOF

# ---------------------------------------------------------------- cargo ---

while read -r crate bin; do
  [[ -z $crate || $crate == \#* ]] && continue
  diver_cargo_pkg "$crate" "${bin:-$crate}"
done <<'EOF'
fnlfmt
just
shellharden
stylua
tex-fmt tex-fmt
tombi
typstfmt
typstyle
EOF

# ------------------------------------------------------------------- go ---

while read -r module bin; do
  [[ -z $module || $module == \#* ]] && continue
  diver_go_pkg "$module" "${bin:-$module}"
done <<'EOF'
cuelang.org/go/cmd/cue@latest cue
github.com/a-h/templ/cmd/templ@latest templ
github.com/google/go-jsonnet/cmd/jsonnetfmt@latest jsonnetfmt
github.com/google/yamlfmt/cmd/yamlfmt@latest yamlfmt
golang.org/x/tools/cmd/goimports@latest goimports
mvdan.cc/gofumpt@latest gofumpt
mvdan.cc/sh/v3/cmd/shfmt@latest shfmt
EOF

# ------------------------------------------------------------------ gem ---

while read -r gem bin; do
  [[ -z $gem || $gem == \#* ]] && continue
  diver_gem_pkg "$gem" "${bin:-$gem}"
done <<'EOF'
cookstyle
erb-formatter erb-format
htmlbeautifier
mdl
puppet-lint
rubocop
standard standardrb
EOF

# ---------------------------------------------------------------- dotnet ---

diver_dotnet_tool csharpier
diver_dotnet_tool fantomas

# ----------------------------------------------------------------- opam ---

diver_opam_pkg ocamlformat

# ---------------------------------------------------------------- cabal ---

# Needs ghcup (cabal on PATH); skipped with a warning otherwise.
for pkg in brittany cabal-fmt fourmolu hledger-fmt ormolu; do
  diver_cabal_pkg "$pkg"
done

# -------------------------------------------------------------- coursier ---

diver_coursier_pkg scalafmt

# -------------------------------------------------------------- composer ---

# Needs php + composer.
diver_composer_pkg squizlabs/php_codesniffer phpcbf
diver_composer_pkg laravel/pint pint

# ------------------------------------------------------------------ phar ---

diver_phar "https://github.com/PHP-CS-Fixer/PHP-CS-Fixer/releases/latest/download/php-cs-fixer.phar" php-cs-fixer
diver_phar "https://github.com/VincentLanglet/Twig-CS-Fixer/releases/latest/download/twig-cs-fixer.phar" twig-cs-fixer

# ----------------------------------------------------------- gh releases ---

# repo | bin | asset-regex (linux)
while IFS='|' read -r repo bin regex; do
  [[ -z $repo || $repo == \#* ]] && continue
  diver_gh_release "$repo" "$bin" "$regex"
done <<'EOF'
kamadorueda/alejandra|alejandra|x86_64-unknown-linux-musl
Azure/bicep|bicep|bicep-linux-x64
biomejs/biome|biome|biome-linux-x64
bufbuild/buf|buf|buf-Linux-x86_64
bazelbuild/buildtools|buildifier|buildifier-linux-amd64
c3lang/c3c|c3lsp|c3-.*linux.*\.tar\.gz
crystal-lang/crystal|crystal|crystal-.*-linux-x86_64\.tar\.gz
terrastruct/d2|d2|d2-.*-linux-amd64\.tar\.gz
dprint/dprint|dprint|dprint-x86_64-unknown-linux-gnu\.zip
gleam-lang/gleam|gleam|gleam-.*-x86_64-unknown-linux-musl\.tar\.gz
grain-lang/grain|grain|grain-.*linux.*\.tar\.gz
hashicorp/nomad|nomad|nomad_.*_linux_amd64\.zip
hashicorp/packer|packer|packer_.*_linux_amd64\.zip
hashicorp/terraform|terraform|terraform_.*_linux_amd64\.zip
opentofu/opentofu|tofu|tofu_.*_linux_amd64\.tar\.gz
open-policy-agent/opa|opa|opa_linux_amd64
jqlang/jq|jq|jq-linux(64|amd64)
pinterest/ktlint|ktlint|^.*/ktlint$
kcl-lang/kcl|kcl|kcl-.*-linux-amd64\.tar\.gz
koka-lang/koka|koka|koka-.*linux.*\.tar\.gz
tweag/nickel|nickel|nickel-.*x86_64.*linux.*\.tar\.gz
vlang/v|v|v_linux\.zip
chipsalliance/verible|verible-verilog-format|verible-.*linux.*\.tar\.gz
ziglang/zig|zig|zig-linux-x86_64-.*\.tar\.xz
EOF

# ------------------------------------------------------------------ misc ---

# pg_format: source build (darold/pgFormatter).
diver_source_make "https://github.com/darold/pgFormatter.git" pg_format

# Dart SDK: zip → ~/.local/share/dart-sdk, link dart.
if ! diver_have dart; then
  dart_ver="3.10.7"
  dart_url="https://storage.googleapis.com/dart-archive/channels/stable/release/${dart_ver}/sdk/dartsdk-linux-x64-release.zip"
  dart_dest="$PREFIX/share/dart-sdk"
  if [[ ! -x $dart_dest/bin/dart ]]; then
    diver_log "installing Dart SDK $dart_ver"
    diver_download_extract "$dart_url" "$PREFIX/share" || diver_warn "Dart SDK download failed"
  fi
  [[ -x $dart_dest/bin/dart ]] && diver_link_bin "$dart_dest/bin/dart" dart
fi
diver_manifest_add dart

# nimpretty: choosenim installs the Nim toolchain into ~/.nimble.
if ! diver_have nimpretty; then
  if [[ -x $HOME/.nimble/bin/nimpretty ]]; then
    diver_link_bin "$HOME/.nimble/bin/nimpretty" nimpretty
  else
    diver_log "installing Nim via choosenim (for nimpretty)"
    if curl -sSfL https://nim-lang.org/choosenim/init.sh -o "$DIVER_TMP_DIR/choosenim.sh"; then
      sh "$DIVER_TMP_DIR/choosenim.sh" -y >/dev/null 2>&1 || diver_warn "choosenim failed"
      [[ -x $HOME/.nimble/bin/nimpretty ]] && diver_link_bin "$HOME/.nimble/bin/nimpretty" nimpretty
    else
      diver_warn "choosenim download failed"
    fi
  fi
fi
diver_manifest_add nimpretty

# zprint: java uberjar.
if ! diver_have zprint; then
  zprint_url="$(_diver_gh_asset_url kkinnear/zprint 'zprint-filter.*\.jar' 2>/dev/null || true)"
  if [[ -n $zprint_url ]]; then
    diver_java_jar "$zprint_url" zprint
  else
    diver_warn "zprint: no uberjar asset found in latest release"
  fi
fi
diver_manifest_add zprint

# swift-format ships with the Swift toolchain (swiftly); swiftformat needs macOS.
if ! diver_have swift-format; then
  diver_warn "swift-format: install the Swift toolchain via swiftly (swift-server/swiftly) — skipped"
fi
diver_manifest_add swift-format
if ! diver_have swiftformat; then
  diver_warn "swiftformat: no clean Linux rootless distribution — skipped"
fi
diver_manifest_add swiftformat

# qmlformat ships with Qt6 — needs a Qt install (aqtinstall is heavy); report.
if ! diver_have qmlformat; then
  diver_warn "qmlformat: ships with Qt6 — install Qt via aqtinstall if needed — skipped"
fi
diver_manifest_add qmlformat

diver_ok "formatters step done"
