#!/usr/bin/env bash
# steps/20-neovim.sh — install Neovim nightly, rootlessly.
#
# Default: build from source (neovim master) as an optimized Release build —
# -O3 -march=native, Ninja generator, clang when available (gcc fallback).
# Slower (~15-45 min first run) but tracks master precisely and runs at
# full speed on the build machine.
#
# Opt-out: DIVER_NVIM_PREBUILT=1 (or install.sh --prebuilt) downloads the
# prebuilt nightly tarball into $PREFIX/nvim-nightly and symlinks
# $BIN_DIR/nvim. Fast (~1 min), no compiler needed.
#
# Tuning (source build):
#   DIVER_NVIM_BUILD_TYPE  Release (default) | RelWithDebInfo | Debug
#   DIVER_NVIM_CFLAGS      C/C++ flags (default "-O3 -march=native")
#   DIVER_NVIM_LTO         1 enables link-time optimization (slower build,
#                          occasionally fails upstream — off by default)
#   DIVER_NVIM_DRY_RUN     1 validates clone + cmake configure, then stops
#                          before compiling (fast toolchain check)
#
# Idempotent: re-running re-installs/updates the nightly in place.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

SOURCE_BUILD="${DIVER_NVIM_SOURCE:-1}"
PREBUILT="${DIVER_NVIM_PREBUILT:-0}"
BUILD_DIR="${BUILD_DIR:-$HOME/src/neovim-nightly}"

nvim_version() {
  "$BIN_DIR/nvim" --version 2>/dev/null | head -1 || true
}

install_nix_on_droid() {
  # Neovim nightly via the community overlay; fall back to nixpkgs stable.
  diver_log "installing neovim via nix profile"
  if diver_nix_install 'github:nix-community/neovim-nightly-overlay#neovim'; then
    diver_ok "neovim (nightly overlay): $(nvim --version 2>/dev/null | head -1)"
  else
    diver_warn "nightly overlay failed — falling back to nixpkgs neovim"
    diver_nix_install 'nixpkgs#neovim' || diver_die "nix profile install neovim failed"
    diver_ok "neovim (nixpkgs): $(nvim --version 2>/dev/null | head -1)"
  fi
}

install_binary() {
  if ((IS_NIX_ON_DROID)); then
    install_nix_on_droid
    return 0
  fi

  if ((IS_TERMUX)); then
    if diver_have nvim; then
      diver_log "Termux: using pkg-provided neovim: $(nvim --version | head -1)"
      return 0
    fi
    diver_log "Termux: installing neovim via pkg"
    pkg install -y neovim || diver_die "pkg install neovim failed"
    return 0
  fi

  local asset_os="$DIVER_OS" asset_arch="$DIVER_ARCH"
  # Upstream nightly asset naming: nvim-linux-x86_64 / nvim-linux-arm64,
  # nvim-macos-x86_64 / nvim-macos-arm64.
  local asset="nvim-${asset_os}-${asset_arch}.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/nightly/${asset}"
  local dest="$PREFIX/nvim-nightly"

  diver_log "installing prebuilt neovim nightly → $dest"
  rm -rf "$dest"
  diver_download_extract "$url" "$dest" 1
  diver_link_bin "$dest/bin/nvim" nvim

  # Ship the runtime from the tarball; nvim resolves it relative to $NVIM_PRGNAME.
  diver_ok "neovim installed: $(nvim_version)"
}

build_from_source() {
  diver_log "building neovim from source (optimized — this takes a while)"

  if ((IS_WSL)); then
    case "$PWD" in
      /mnt/*)
        diver_warn "WSL2: building under /mnt is slow (9P overhead) — prefer ~/"
        ;;
    esac
  fi

  # A global url.git@github.com:.insteadOf=https://github.com/ rewrite breaks
  # https clones/fetches when the SSH key is missing/broken. Neutralize the
  # global config for the network-touching git operations only — the
  # checkout itself keeps its own .git/config. (Each installer step runs in
  # its own bash process, so this export is step-scoped.)
  if git config --global url.git@github.com:.insteadOf >/dev/null 2>&1; then
    diver_log "global git rewrites github https→ssh — neutralizing for this step (https)"
    export GIT_CONFIG_GLOBAL=/dev/null
  fi

  if [[ -d "$BUILD_DIR/.git" ]]; then
    cd "$BUILD_DIR"
    git fetch --all --tags
  else
    git clone https://github.com/neovim/neovim "$BUILD_DIR" --recursive
    cd "$BUILD_DIR"
  fi
  git switch master || git checkout master
  rm -rf build .deps

  # Thin-LTO linking writes multi-GB temp files to $TMPDIR (default /tmp),
  # which is often a small tmpfs. Point it at the roomy build disk instead.
  mkdir -p "$BUILD_DIR/.tmp"
  export TMPDIR="$BUILD_DIR/.tmp"

  if ((IS_TERMUX)); then
    export CC="${CC:-clang}"
    export CXX="${CXX:-clang++}"
    export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
  fi

  local build_type="${DIVER_NVIM_BUILD_TYPE:-Release}"
  local cflags="${DIVER_NVIM_CFLAGS:--O3 -march=native}"
  local extra_defs=()

  # Prefer clang (bootstrapped by 10-prereqs when missing), fall back to gcc.
  local cc_bin="" cxx_bin=""
  if ! ((IS_TERMUX)); then
    if diver_have clang && diver_have clang++; then
      cc_bin="clang"
      cxx_bin="clang++"
    elif diver_have gcc && diver_have g++; then
      cc_bin="gcc"
      cxx_bin="g++"
    else
      diver_die "no C compiler found — re-run step 10-prereqs first"
    fi
    diver_log "compiler: $cc_bin ($("$cc_bin" --version | head -1))"
  fi

  if [[ ${DIVER_NVIM_LTO:-0} == 1 ]]; then
    extra_defs+=("-DENABLE_LTO=ON")
    diver_log "LTO enabled (slower build)"
  fi
  diver_log "build type: $build_type | flags: $cflags"

  local compiler_defs=()
  if [[ -n $cc_bin ]]; then
    compiler_defs=(
      -D "CMAKE_C_COMPILER=$cc_bin"
      -D "CMAKE_CXX_COMPILER=$cxx_bin"
    )
  fi

  cmake -S cmake.deps -B .deps -G Ninja \
    -D "CMAKE_BUILD_TYPE=$build_type" \
    -D "CMAKE_C_FLAGS=$cflags" \
    -D "CMAKE_CXX_FLAGS=$cflags" \
    -D USE_BUNDLED=ON \
    -D USE_BUNDLED_LUAJIT=ON \
    "${compiler_defs[@]}" \
    "${extra_defs[@]}"

  if [[ ${DIVER_NVIM_DRY_RUN:-0} == 1 ]]; then
    diver_ok "dry run: clone + cmake configure OK — deps build/install skipped"
    return 0
  fi

  cmake --build .deps
  cmake -B build -G Ninja \
    -D "CMAKE_BUILD_TYPE=$build_type" \
    -D "CMAKE_C_FLAGS=$cflags" \
    -D "CMAKE_CXX_FLAGS=$cflags" \
    -D "CMAKE_INSTALL_PREFIX=$PREFIX" \
    "${compiler_defs[@]}" \
    "${extra_defs[@]}"
  cmake --build build
  cmake --install build

  # Make the freshly built runtime visible under the XDG data dir and
  # ensure init.lua prepends it (preserves old quickstart behaviour).
  # NOTE: neovim installs its runtime via CMAKE_INSTALL_DATAROOTDIR
  # (default: $PREFIX/share), so with the default PREFIX=$HOME/.local the
  # source and destination below are the SAME directory — only copy when
  # a custom PREFIX/XDG_DATA_HOME makes them differ.
  local runtime_src="$PREFIX/share/nvim/runtime"
  local runtime_dest="$NVIM_DATA_DIR/runtime"
  local init_lua="$XDG_CONFIG_HOME/nvim/init.lua"
  if [[ $runtime_src != "$runtime_dest" && -d $runtime_src ]]; then
    mkdir -p "$NVIM_DATA_DIR"
    if [[ -d $runtime_dest ]] && [[ ! -L $runtime_dest ]]; then
      mv "$runtime_dest" "${runtime_dest}.backup-$(date +%s)"
    fi
    [[ -L $runtime_dest ]] && rm "$runtime_dest"
    cp -r "$runtime_src" "$runtime_dest"
    mkdir -p "$(dirname "$init_lua")"
    local runtime_block='local data_runtime = vim.fn.stdpath("data") .. "/runtime"
if vim.fn.isdirectory(data_runtime) == 1 then
  vim.opt.runtimepath:prepend(data_runtime)
end
'
    if [[ -f $init_lua ]]; then
      if ! grep -q 'stdpath.*runtime' "$init_lua"; then
        echo "$runtime_block" | cat - "$init_lua" >"$init_lua.tmp"
        mv "$init_lua.tmp" "$init_lua"
        diver_log "runtime block added to $init_lua"
      fi
    else
      printf '%s' "$runtime_block" >"$init_lua"
      diver_log "created $init_lua with runtime setup"
    fi
  fi

  [[ -d $runtime_dest ]] || diver_die "runtime missing after install: $runtime_dest"
  diver_ok "neovim built from source: $(nvim_version)"
}

if [[ $PREBUILT == 1 || $SOURCE_BUILD == 0 ]]; then
  install_binary
else
  build_from_source
fi

if [[ ${DIVER_NVIM_DRY_RUN:-0} != 1 ]]; then
  diver_have nvim || diver_die "neovim not on PATH after install"
fi
