#!/usr/bin/env bash
# steps/40-toolchains.sh — ensure language toolchains exist, rootlessly.
#
# The LSP/formatter/linter installers assume their ecosystem toolchain is
# present. This step fills the gaps with user-local installs:
#   go      → official tarball into $PREFIX/go
#   rust    → rustup-init (rootless by design: ~/.rustup, ~/.cargo)
#   node    → official binary tarball into $PREFIX/node (+ pnpm via corepack)
#   python  → uv binary into $BIN_DIR, then `uv python install` (no system python needed)
#   java    → Temurin JDK tarball into $PREFIX/java (needed by java-based LSPs)
#
# Best-effort: a toolchain that cannot be installed is reported, never fatal.
# Re-running only fills gaps.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

skipped=()

if ((IS_NIX_ON_DROID)); then
  diver_log "Nix-on-Droid: installing toolchains via nix profile (user scope)"
  diver_nix_install nixpkgs#go || skipped+=("go")
  diver_nix_install nixpkgs#rustup || skipped+=("rustup")
  diver_nix_install nixpkgs#nodejs || skipped+=("node")
  diver_nix_install nixpkgs#python3 nixpkgs#uv || skipped+=("python/uv")
  diver_nix_install nixpkgs#temurin-bin || skipped+=("java")
  # pnpm via corepack once node is present.
  if diver_have corepack; then
    corepack prepare pnpm@latest --activate >/dev/null 2>&1 || true
  fi
  diver_have ruby && diver_log "ruby: $(ruby --version)" || skipped+=("ruby (nixpkgs#ruby)")
  echo
  if ((${#skipped[@]} > 0)); then
    diver_warn "toolchains still missing: ${skipped[*]}"
  else
    diver_ok "all toolchains present"
  fi
  exit 0
fi

with_go() {
  if diver_have go; then
    diver_log "go: $(go version)"
    return 0
  fi
  ((IS_TERMUX)) && {
    pkg install -y golang 2>/dev/null || true
    diver_have go && return 0
  }
  local ver="1.25.1"
  local goarch="$DIVER_ARCH"
  [[ $goarch == "x86_64" ]] && goarch="amd64"
  [[ $goarch == "aarch64" ]] && goarch="arm64"
  local url="https://go.dev/dl/go${ver}.${DIVER_OS}-${goarch}.tar.gz"
  local dest="$PREFIX/go-${ver}"
  if [[ $DIVER_OS != "linux" && $DIVER_OS != "android" ]]; then
    diver_warn "no Go bootstrap recipe for $DIVER_OS"
    return 1
  fi
  diver_log "installing Go $ver → $dest"
  diver_download_extract "$url" "$dest" 1 || return 1
  diver_link_bin "$dest/bin/go" go
  diver_link_bin "$dest/bin/gofmt" gofmt
  export GOBIN="${XDG_BIN_HOME:-$HOME/.local/bin}"
  export PATH="$GOBIN:$PATH"
  diver_ok "go: $(go version)"
}

with_rust() {
  if diver_have cargo; then
    diver_log "cargo: $(cargo --version)"
    return 0
  fi
  ((IS_TERMUX)) && {
    pkg install -y rust 2>/dev/null || true
    diver_have cargo && return 0
  }
  diver_log "installing rustup (rootless: ~/.rustup, ~/.cargo)"
  local init="$DIVER_TMP_DIR/rustup-init.sh"
  curl -L --fail --retry 3 -o "$init" https://sh.rustup.rs || return 1
  sh "$init" -y --profile minimal --no-modify-path || return 1
  export PATH="$HOME/.cargo/bin:$PATH"
  diver_have cargo || return 1
  diver_ok "cargo: $(cargo --version)"
}

with_node() {
  if diver_have node; then
    diver_log "node: $(node --version)"
  else
    ((IS_TERMUX)) && {
      pkg install -y nodejs 2>/dev/null || true
      diver_have node || return 1
    }
    local ver="24.11.0"
    local nodearch="$DIVER_ARCH"
    [[ $nodearch == "x86_64" ]] && nodearch="x64"
    [[ $nodearch == "aarch64" ]] && nodearch="arm64"
    local url="https://nodejs.org/dist/v${ver}/node-v${ver}-${DIVER_OS}-${nodearch}.tar.xz"
    local dest="$PREFIX/node-${ver}"
    diver_log "installing Node $ver → $dest"
    diver_download_extract "$url" "$dest" 1 || return 1
    diver_link_bin "$dest/bin/node" node
    diver_link_bin "$dest/bin/npm" npm
    diver_link_bin "$dest/bin/npx" npx
    diver_log "node: $(node --version)"
  fi
  # pnpm via corepack (ships with node) — user-global store, no root.
  if ! diver_have pnpm; then
    diver_log "enabling pnpm via corepack"
    corepack enable >/dev/null 2>&1 || true
    corepack prepare pnpm@latest --activate >/dev/null 2>&1 || npm install -g pnpm || true
  fi
  diver_have pnpm && diver_log "pnpm: $(pnpm --version)" || diver_warn "pnpm unavailable"
  return 0
}

with_python() {
  if diver_have uv; then
    diver_log "uv: $(uv --version)"
  else
    diver_log "installing uv (standalone binary)"
    local uvdir="$PREFIX/uv"
    mkdir -p "$uvdir"
    # uv publishes a self-contained binary per arch.
    local uvzip="$DIVER_TMP_DIR/uv.tar.gz"
    local uvver="0.8.22"
    local uvarch="$DIVER_ARCH"
    [[ $uvarch == "aarch64" ]] && uvarch="aarch64"
    curl -L --fail --retry 3 \
      -o "$uvzip" "https://github.com/astral-sh/uv/releases/download/${uvver}/uv-${uvarch}-unknown-linux-gnu.tar.gz" || return 1
    tar -xzf "$uvzip" -C "$uvdir" --strip-components=1
    diver_link_bin "$uvdir/uv" uv
    diver_have uv || return 1
  fi
  # Ensure a usable python3 without touching the system one.
  if ! diver_have python3; then
    diver_log "installing user-local python via uv"
    uv python install --install-dir "$PREFIX/python" 2>/dev/null || true
    # Link the newest installed python3.
    local pybin
    pybin="$(find "$PREFIX/python" -maxdepth 3 -name 'python3*' -type f 2>/dev/null | sort | tail -1 || true)"
    [[ -n $pybin ]] && diver_link_bin "$pybin" python3
  fi
  diver_have python3 && diver_log "python3: $(python3 --version 2>&1)" || diver_warn "python3 unavailable"
  return 0
}

with_java() {
  if diver_have java; then
    diver_log "java: $(java -version 2>&1 | head -1)"
    return 0
  fi
  ((IS_TERMUX)) && {
    pkg install -y openjdk-17 2>/dev/null || true
    diver_have java && return 0
  }
  # Temurin 21 LTS tarball — needed by java-based LSPs (jdtls, apex, …).
  local ver="21.0.8+9"
  local urlver="21.0.8_9"
  local jarch="$DIVER_ARCH"
  [[ $jarch == "aarch64" ]] && jarch="aarch64"
  local url="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${ver}/OpenJDK21U-jdk_${jarch}_linux_hotspot_${urlver}.tar.gz"
  local dest="$PREFIX/java-21"
  diver_log "installing Temurin JDK 21 → $dest"
  diver_download_extract "$url" "$dest" 1 || return 1
  diver_link_bin "$dest/bin/java" java
  diver_log "java: $(java -version 2>&1 | head -1)"
}

with_go || skipped+=("go")
with_rust || skipped+=("rust")
with_node || skipped+=("node")
with_python || skipped+=("python")
with_java || skipped+=("java")

# Ruby: building from source is slow and version managers are a personal
# choice — report only.
if diver_have ruby; then
  diver_log "ruby: $(ruby --version)"
else
  skipped+=("ruby (install rbenv/ruby-build or your distro package — no automated recipe)")
fi

echo
if ((${#skipped[@]} > 0)); then
  diver_warn "toolchains still missing: ${skipped[*]}"
  diver_warn "ecosystem installers that need them will report their own errors"
else
  diver_ok "all toolchains present"
fi
