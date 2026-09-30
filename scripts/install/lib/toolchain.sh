#!/usr/bin/env bash
# scripts/install/lib/toolchain.sh
# Channel-installer primitives for steps 60/70/80 (formatters, linters, DAP).
#
# Every installer is: skip when the binary is already on PATH, install
# user-locally otherwise, never fatal on its own (the caller decides).
# Sourced by the steps; requires common.sh already sourced.
#
# Provides:
#   diver_manifest_add <bin>...   record binaries this step manages
#   diver_uv_tool      <pkg> [bin]
#   diver_npm_global   <pkg> [bin]
#   diver_cargo_pkg    <crate> [bin] [extra-args...]
#   diver_go_pkg       <module@version> [bin]
#   diver_gem_pkg      <gem> [bin]
#   diver_cpan_pkg     <dist> [bin]
#   diver_luarocks_pkg <rock> [bin]
#   diver_dotnet_tool  <pkg> [bin]
#   diver_opam_pkg     <pkg> [bin]
#   diver_cabal_pkg    <pkg> [bin]
#   diver_coursier_pkg <artifact> [bin]
#   diver_composer_pkg <pkg> [bin]
#   diver_gh_release   <owner/repo> <bin> <asset-regex>
#   diver_java_jar     <url> <name>        (wrapper: java -jar)
#   diver_phar         <url> <name>        (wrapper: php <phar>)
#   diver_vsix         <url> <name>        (extract VSIX under XDG_DATA_HOME)
#   diver_curl_script  <url> <name>        (single-file script into $BIN_DIR)
#   diver_source_make  <git-url> <name> <make-args...>
#   DIVER_UNSUPPORTED  array — binaries with no clean rootless install path

# ---------------------------------------------------------------- manifest ---

# diver_manifest_add <bin>...
# Records binaries managed by the calling step so 99-finish can probe them.
diver_manifest_add() {
  local manifest_dir="$XDG_DATA_HOME/diver/install/manifest.d"
  local step_name
  step_name="$(basename "${BASH_SOURCE[1]}" .sh)"
  mkdir -p "$manifest_dir"
  local b
  for b in "$@"; do
    printf '%s\n' "$b" >>"$manifest_dir/$step_name.txt"
  done
  sort -u -o "$manifest_dir/$step_name.txt" "$manifest_dir/$step_name.txt"
}

# ---------------------------------------------------------------- helpers ---

# _diver_try <bin> <label> <cmd...>
# Skip when <bin> is on PATH; otherwise run the install command, warn on failure.
_diver_try() {
  local bin=$1 label=$2
  shift 2
  if diver_have "$bin"; then
    return 0
  fi
  diver_log "installing $label"
  if "$@" >/dev/null 2>&1; then
    diver_have "$bin" && diver_ok "$label → $bin" || diver_warn "$label installed but $bin not on PATH"
  else
    diver_warn "$label failed (continuing)"
  fi
  return 0
}

_diver_need() {
  # _diver_need <tool> <what-for> — true when <tool> exists, warns otherwise.
  if diver_have "$1"; then
    return 0
  fi
  diver_warn "skipping $2: '$1' not on PATH"
  return 1
}

# ---------------------------------------------------------------- channels ---

diver_uv_tool() {
  # diver_uv_tool <pkg> [bin] — uv tool install (default bin = pkg).
  local pkg=$1 bin=${2:-$1}
  _diver_need uv "$pkg" || return 0
  _diver_try "$bin" "$pkg (uv)" uv tool install "$pkg"
  diver_manifest_add "$bin"
}

diver_npm_global() {
  # diver_npm_global <pkg> [bin] — npm install -g (default bin = pkg).
  local pkg=$1 bin=${2:-$1}
  _diver_need npm "$pkg" || return 0
  _diver_try "$bin" "$pkg (npm)" npm install -g "$pkg"
  diver_manifest_add "$bin"
}

diver_cargo_pkg() {
  # diver_cargo_pkg <crate> [bin] [extra args...]
  local crate=$1 bin=${2:-$1}
  shift 2 || true
  _diver_need cargo "$crate" || return 0
  if diver_have "$bin"; then
    diver_manifest_add "$bin"
    return 0
  fi
  diver_log "installing $crate (cargo)"
  if cargo install "$crate" "$@" >/dev/null 2>&1; then
    diver_have "$bin" && diver_ok "$crate → $bin" || diver_warn "$crate installed but $bin not on PATH"
  else
    diver_warn "$crate failed (continuing)"
  fi
  diver_manifest_add "$bin"
}

diver_go_pkg() {
  # diver_go_pkg <module@version> [bin]
  local module=$1 bin=${2:-$1}
  _diver_need go "$module" || return 0
  if diver_have "$bin"; then
    diver_manifest_add "$bin"
    return 0
  fi
  diver_log "installing $module (go)"
  if GOBIN="$BIN_DIR" go install "$module" >/dev/null 2>&1; then
    diver_have "$bin" && diver_ok "$module → $bin" || diver_warn "$module installed but $bin not on PATH"
  else
    diver_warn "$module failed (continuing)"
  fi
  diver_manifest_add "$bin"
}

diver_gem_pkg() {
  # diver_gem_pkg <gem> [bin]
  local gem=$1 bin=${2:-$1}
  _diver_need gem "$gem" || return 0
  _diver_try "$bin" "$gem (gem)" gem install --user-install --no-document "$gem"
  diver_manifest_add "$bin"
}

diver_cpan_pkg() {
  # diver_cpan_pkg <dist> [bin] — cpanm into ~/perl5 (local::lib).
  local dist=$1 bin=${2:-$1}
  _diver_need cpanm "$dist" || return 0
  _diver_try "$bin" "$dist (cpanm)" cpanm --local-lib="$HOME/perl5" --notest "$dist"
  diver_manifest_add "$bin"
}

diver_luarocks_pkg() {
  # diver_luarocks_pkg <rock> [bin]
  local rock=$1 bin=${2:-$1}
  _diver_need luarocks "$rock" || return 0
  _diver_try "$bin" "$rock (luarocks)" luarocks install --local "$rock"
  diver_manifest_add "$bin"
}

diver_dotnet_tool() {
  # diver_dotnet_tool <pkg> [bin]
  local pkg=$1 bin=${2:-$1}
  _diver_need dotnet "$pkg" || return 0
  _diver_try "$bin" "$pkg (dotnet tool)" dotnet tool install -g "$pkg"
  diver_manifest_add "$bin"
}

diver_opam_pkg() {
  # diver_opam_pkg <pkg> [bin] — needs an opam switch already initialised.
  local pkg=$1 bin=${2:-$1}
  _diver_need opam "$pkg" || return 0
  _diver_try "$bin" "$pkg (opam)" opam install -y "$pkg"
  diver_manifest_add "$bin"
}

diver_cabal_pkg() {
  # diver_cabal_pkg <pkg> [bin] — needs ghcup/cabal.
  local pkg=$1 bin=${2:-$1}
  _diver_need cabal "$pkg" || return 0
  _diver_try "$bin" "$pkg (cabal)" cabal install "$pkg"
  diver_manifest_add "$bin"
}

diver_coursier_pkg() {
  # diver_coursier_pkg <artifact> [bin] — coursier install (needs JVM).
  local artifact=$1 bin=${2:-$1}
  _diver_need coursier "$artifact" || return 0
  _diver_need java "$artifact" || return 0
  _diver_try "$bin" "$artifact (coursier)" coursier install "$artifact"
  diver_manifest_add "$bin"
}

diver_composer_pkg() {
  # diver_composer_pkg <pkg> [bin] — composer global require (needs php).
  local pkg=$1 bin=${2:-$1}
  _diver_need composer "$pkg" || return 0
  _diver_need php "$pkg" || return 0
  _diver_try "$bin" "$pkg (composer)" composer global require "$pkg"
  diver_manifest_add "$bin"
}

# ------------------------------------------------------------- gh release ---

_diver_gh_latest_json() {
  # Print the latest-release JSON for owner/repo (python3 preferred).
  local repo=$1
  curl -sL --fail --retry 2 "https://api.github.com/repos/$repo/releases/latest"
}

_diver_gh_asset_url() {
  # _diver_gh_asset_url <owner/repo> <asset-regex> — print browser_download_url.
  local repo=$1 regex=$2 json url
  json="$(_diver_gh_latest_json "$repo")" || return 1
  if diver_have python3; then
    url="$(printf '%s' "$json" | python3 -c "
import json, re, sys
data = json.load(sys.stdin)
pat = re.compile(sys.argv[1])
for a in data.get('assets', []):
    u = a.get('browser_download_url', '')
    if pat.search(u):
        print(u); break
" "$regex")" || return 1
  else
    url="$(printf '%s' "$json" | grep -o "\"browser_download_url\": *\"[^\"]*$regex[^\"]*\"" | head -1 | sed 's/.*": *"//; s/"$//')" || return 1
  fi
  [[ -n $url ]] || return 1
  printf '%s' "$url"
}

diver_gh_release() {
  # diver_gh_release <owner/repo> <bin> <asset-regex>
  # Latest release → download the asset matching <asset-regex> → extract →
  # find executable <bin> → link into $BIN_DIR. Verifies a sibling .sha256
  # asset when the release publishes one.
  local repo=$1 bin=$2 regex=$3
  if diver_have "$bin"; then
    diver_manifest_add "$bin"
    return 0
  fi
  local url
  if ! url="$(_diver_gh_asset_url "$repo" "$regex")"; then
    diver_warn "$repo: no release asset matching /$regex/"
    diver_manifest_add "$bin"
    return 0
  fi
  local tmp="$DIVER_TMP_DIR/gh-$bin"
  local dest="$PREFIX/share/diver-gh/$bin"
  rm -rf "$tmp" "$dest"
  mkdir -p "$tmp" "$dest"
  local fname="$tmp/$(basename "$url")"
  diver_log "installing $bin ← $repo"
  if ! curl -sL --fail --retry 3 -o "$fname" "$url"; then
    diver_warn "$bin: download failed"
    diver_manifest_add "$bin"
    return 0
  fi
  # Checksum when upstream publishes "<asset>.sha256".
  if curl -sL --fail -o "$fname.sha256" "$url.sha256" 2>/dev/null; then
    if (cd "$tmp" && sha256sum -c "$(basename "$fname").sha256" >/dev/null 2>&1); then
      diver_log "$bin: sha256 verified"
    else
      diver_warn "$bin: sha256 mismatch — refusing to install"
      diver_manifest_add "$bin"
      return 0
    fi
  fi
  case "$fname" in
    *.tar.gz | *.tgz) tar -xzf "$fname" -C "$dest" ;;
    *.tar.xz) tar -xJf "$fname" -C "$dest" ;;
    *.tar.bz2) tar -xjf "$fname" -C "$dest" ;;
    *.zip) unzip -q "$fname" -d "$dest" ;;
    *)
      # Single-file binary release.
      chmod +x "$fname"
      diver_link_bin "$fname" "$bin"
      diver_ok "$bin (single-file release)"
      diver_manifest_add "$bin"
      return 0
      ;;
  esac
  local found
  found="$(find "$dest" -type f -name "$bin" -perm -u+x 2>/dev/null | head -1)"
  [[ -z $found ]] && found="$(find "$dest" -type f -name "$bin" 2>/dev/null | head -1)"
  if [[ -n $found ]]; then
    diver_link_bin "$found" "$bin"
    diver_ok "$bin → $(basename "$found")"
  else
    diver_warn "$bin: extracted but no '$bin' executable found under $dest"
  fi
  diver_manifest_add "$bin"
}

# ------------------------------------------------------- jar/phar/script ---

diver_java_jar() {
  # diver_java_jar <url> <name> — download jar, wrapper script java -jar.
  local url=$1 name=$2
  _diver_need java "$name" || return 0
  local jar_dir="$XDG_DATA_HOME/diver/jars"
  mkdir -p "$jar_dir" "$BIN_DIR"
  local jar="$jar_dir/$name.jar"
  if [[ ! -f $jar ]]; then
    diver_log "installing $name (jar)"
    curl -sL --fail --retry 3 -o "$jar" "$url" || {
      diver_warn "$name: jar download failed"
      diver_manifest_add "$name"
      return 0
    }
  fi
  printf '#!/usr/bin/env bash\nexec java -jar "%s" "$@"\n' "$jar" >"$BIN_DIR/$name"
  chmod +x "$BIN_DIR/$name"
  diver_ok "$name (java -jar wrapper)"
  diver_manifest_add "$name"
}

diver_phar() {
  # diver_phar <url> <name> — download .phar, wrapper script php <phar>.
  local url=$1 name=$2
  _diver_need php "$name" || return 0
  local phar_dir="$XDG_DATA_HOME/diver/phars"
  mkdir -p "$phar_dir" "$BIN_DIR"
  local phar="$phar_dir/$name.phar"
  if [[ ! -f $phar ]]; then
    diver_log "installing $name (phar)"
    curl -sL --fail --retry 3 -o "$phar" "$url" || {
      diver_warn "$name: phar download failed"
      diver_manifest_add "$name"
      return 0
    }
  fi
  chmod +x "$phar"
  printf '#!/usr/bin/env bash\nexec php "%s" "$@"\n' "$phar" >"$BIN_DIR/$name"
  chmod +x "$BIN_DIR/$name"
  diver_ok "$name (php wrapper)"
  diver_manifest_add "$name"
}

diver_vsix() {
  # diver_vsix <url> <name> — download VSIX (a zip), extract under
  # $XDG_DATA_HOME/diver/vsix/<name>. Prints the extract dir for wrappers.
  local url=$1 name=$2
  local dest="$XDG_DATA_HOME/diver/vsix/$name"
  if [[ ! -d $dest ]]; then
    diver_log "installing $name (VSIX)"
    local out="$DIVER_TMP_DIR/$name.vsix"
    curl -sL --fail --retry 3 -o "$out" "$url" || {
      diver_warn "$name: VSIX download failed"
      return 1
    }
    mkdir -p "$dest"
    unzip -q -o "$out" -d "$dest" || {
      diver_warn "$name: VSIX extract failed"
      return 1
    }
  fi
  printf '%s' "$dest"
}

diver_curl_script() {
  # diver_curl_script <url> <name> — single-file script straight into $BIN_DIR.
  local url=$1 name=$2
  if diver_have "$name"; then
    diver_manifest_add "$name"
    return 0
  fi
  diver_log "installing $name (single-file script)"
  mkdir -p "$BIN_DIR"
  if curl -sL --fail --retry 3 -o "$BIN_DIR/$name" "$url"; then
    chmod +x "$BIN_DIR/$name"
    diver_ok "$name"
  else
    diver_warn "$name: download failed"
  fi
  diver_manifest_add "$name"
}

diver_source_make() {
  # diver_source_make <git-url> <name> [make args...] — clone, make PREFIX=$PREFIX install.
  local git_url=$1 name=$2
  shift 2
  if diver_have "$name"; then
    diver_manifest_add "$name"
    return 0
  fi
  _diver_need git "$name" || return 0
  _diver_need make "$name" || return 0
  local src="$DIVER_TMP_DIR/src-$name"
  diver_log "installing $name (source build)"
  rm -rf "$src"
  if ! git clone --depth 1 "$git_url" "$src" >/dev/null 2>&1; then
    diver_warn "$name: clone failed"
    diver_manifest_add "$name"
    return 0
  fi
  if (cd "$src" && make PREFIX="$PREFIX" "$@" >/dev/null 2>&1 && make PREFIX="$PREFIX" install "$@" >/dev/null 2>&1); then
    diver_have "$name" && diver_ok "$name (source)" || diver_warn "$name: build ok but not on PATH"
  else
    diver_warn "$name: source build failed"
  fi
  diver_manifest_add "$name"
}

# ------------------------------------------------------------- unsupported ---

# Binaries referenced by Diver configs with no clean rootless install path.
# 99-finish reports these honestly instead of pretending they installed.
DIVER_UNSUPPORTED=(
  apkbuild-lint   # Alpine-only script; curl fallback attempted in 70-linters
  bashlint        # no verified install path
  betterleaks     # no verified install path
  checkpatch.pl   # kernel.org single-file script; curl fallback in 70-linters
  desktop-file-validate  # system package only (desktop-file-utils)
  fieldalignment  # no verified install path
  fish            # no clean rootless package (source build possible, skipped)
  hh_client       # ships with hhvm/hack; no rootless distribution
  hlasm_language_server  # proprietary IBM HLASM; no public path
  ksh             # no clean rootless package
  lint-openapi    # no verified install path
  llvm-mc         # only via a full LLVM build (see scripts/lsp/clir_ls.sh)
  matlab          # proprietary; needs a licensed MathWorks install
  mbake           # no verified install path
  mh_lint         # no verified install path
  mh_style        # no verified install path
  nvcc            # CUDA toolkit installer requires root
  panache         # no verified install path
  psfmt           # no verified install path
  schemat         # no verified install path
  secfixes-check  # no verified install path
  systemd-analyze # part of systemd; cannot install rootlessly
  unmake          # no verified install path
  zsh             # no clean rootless package (source build possible, skipped)
)
