#!/usr/bin/env bash
# scripts/install/lib/common.sh
# Shared helpers for the Diver rootless install cascade.
# Every step sources this file. It never installs anything itself.
#
# Sourced, not executed. Requires bash.
#
# Provides:
#   diver_log / diver_ok / diver_warn / diver_err / diver_step
#   diver_detect_platform   - sets IS_WSL, IS_TERMUX, DIVER_OS, DIVER_ARCH,
#                             PREFIX, BIN_DIR, XDG_*_HOME, NVIM_DATA_DIR
#   diver_download_extract  - curl a tarball/zip into a directory
#   diver_require_cmd       - fatal if a command is missing
#   diver_have              - true if a command exists
#   diver_link_bin          - symlink a file into $BIN_DIR
#   diver_ensure_path_rc    - idempotently add $BIN_DIR to shell startup files

set -euo pipefail

# ---------------------------------------------------------------- logging ---

diver_log()  { printf '%s\n' "→ $*"; }
diver_ok()   { printf '%s\n' "✓ $*"; }
diver_warn() { printf '%s\n' "⚠ $*" >&2; }
diver_err()  { printf '%s\n' "!! $*" >&2; }
diver_step() { printf '\n%s\n' "=== $* ==="; }

diver_die() {
  diver_err "$*"
  exit 1
}

# ------------------------------------------------------------------ misc ---

# diver_have <cmd> — true when <cmd> resolves on PATH.
diver_have() {
  command -v "$1" >/dev/null 2>&1
}

# diver_require_cmd <cmd> — fatal when <cmd> is missing.
diver_require_cmd() {
  diver_have "$1" || diver_die "required command not found: $1"
}

# diver_link_bin <target> <link-name>
# Symlink <target> into $BIN_DIR as <link-name> (idempotent).
diver_link_bin() {
  local target=$1 name=$2
  mkdir -p "$BIN_DIR"
  ln -sfn "$target" "$BIN_DIR/$name"
  chmod +x "$target" 2>/dev/null || true
}

# ---------------------------------------------------------------- platform ---

# diver_detect_platform
# Detects WSL/Termux, normalises OS/ARCH, and exports the install layout.
# Everything installs under the user's home — no root required, ever.
diver_detect_platform() {
  IS_WSL=0
  IS_TERMUX=0
  IS_NIX_ON_DROID=0

  case "$(uname -s)" in
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL=1
      fi
      ;;
  esac

  # Nix-on-Droid (Android, com.termux.nix): nix user profiles are the
  # rootless package story — `nix profile install nixpkgs#<pkg>`.
  if command -v nix-on-droid >/dev/null 2>&1; then
    IS_NIX_ON_DROID=1
  fi

  if [[ ${PREFIX-} == *com.termux* ]] \
    || [[ ${SHELL-} == *com.termux* ]] \
    || [[ ${HOME} == *com.termux* ]]; then
    IS_TERMUX=1
  fi

  if ((IS_NIX_ON_DROID)); then
    # nix profile bins live here; ensure they're on PATH even in non-login shells.
    export PATH="$HOME/.nix-profile/bin:$PATH"
    PREFIX="${PREFIX:-$HOME/.local}"
    DIVER_OS='linux'
    DIVER_ARCH="$(uname -m)"
  elif ((IS_TERMUX)); then
    PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    DIVER_OS='android'
  else
    PREFIX="${HOME}/.local"
    DIVER_OS='linux'
  fi

  DIVER_ARCH="$(uname -m)"
  case "$DIVER_ARCH" in
    x86_64) DIVER_ARCH='x86_64' ;;
    aarch64 | arm64) DIVER_ARCH='aarch64' ;;
    *) diver_warn "untested architecture: $DIVER_ARCH" ;;
  esac

  BIN_DIR="$PREFIX/bin"
  XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
  NVIM_DATA_DIR="$XDG_DATA_HOME/nvim"

  export IS_WSL IS_TERMUX IS_NIX_ON_DROID DIVER_OS DIVER_ARCH PREFIX BIN_DIR \
    XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME NVIM_DATA_DIR

  export PATH="$BIN_DIR:$PATH"
}

# ------------------------------------------------------------------- nix ---

# diver_nix_install <flake-ref>... — `nix profile install` wrapper for
# Nix-on-Droid. Idempotent-ish: skips refs already in the profile.
diver_nix_install() {
  local ref
  for ref in "$@"; do
    local name="${ref##*#}"
    # `nix profile list` prints "Name: <pname>-<version>" lines. Anchor the
    # name at the start of the Name field (version separator: - . or space)
    # so e.g. `ruff` does not match `ruff-lsp`. Also match the full flake
    # ref in case the attribute name differs from the pname.
    if nix profile list 2>/dev/null | grep -qE "^Name:[[:space:]]+${name}([-. ]|$)" \
      || nix profile list 2>/dev/null | grep -qF "$ref"; then
      diver_log "nix profile: $name already installed"
      continue
    fi
    diver_log "nix profile install $ref"
    if nix --extra-experimental-features 'nix-command flakes' profile install "$ref"; then
      diver_ok "installed $name"
    else
      diver_warn "nix profile install failed: $ref"
      return 1
    fi
  done
}

# ---------------------------------------------------------------- download ---

# diver_download_extract <url> <dest-dir> [strip-components]
# Downloads an archive with curl and extracts tar.gz / tar.xz / zip.
diver_download_extract() {
  local url=$1 dest_dir=$2 strip_top=${3:-0}
  local tmp_dir="${DIVER_TMP_DIR:?DIVER_TMP_DIR must be set by the orchestrator}"
  mkdir -p "$dest_dir"
  local fname="$tmp_dir/$(basename "$url")"
  diver_log "fetching $(basename "$url")"
  curl -L --fail --retry 3 -o "$fname" "$url"
  case "$fname" in
    *.tar.gz | *.tgz)
      if ((strip_top == 1)); then
        tar -xzf "$fname" -C "$dest_dir" --strip-components=1
      else
        tar -xzf "$fname" -C "$dest_dir"
      fi
      ;;
    *.tar.xz)
      if ((strip_top == 1)); then
        tar -xJf "$fname" -C "$dest_dir" --strip-components=1
      else
        tar -xJf "$fname" -C "$dest_dir"
      fi
      ;;
    *.zip)
      unzip -q "$fname" -d "$dest_dir"
      ;;
    *)
      diver_die "unknown archive format: $fname"
      ;;
  esac
}

# --------------------------------------------------------------- shell rc ---

# diver_ensure_path_rc — idempotently prepend $BIN_DIR to PATH in shell rcs.
diver_ensure_path_rc() {
  local add_path_line="export PATH=\"$BIN_DIR:\$PATH\""
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish" "$HOME/.profile"; do
    [[ -f $rc ]] || continue
    if ! grep -Fq "$BIN_DIR" "$rc"; then
      printf '\n# Added by Diver installer (scripts/install.sh)\n%s\n' "$add_path_line" >>"$rc"
      diver_log "PATH updated in $rc"
    fi
  done
}
