#!/usr/bin/env bash
# steps/80-dap.sh — install Debug Adapter Protocol backends, rootlessly.
#
# Diver's DAP configs resolve adapters at runtime (absolute paths, Mason
# package dirs, or `cmd` binaries). This step installs the backing tools so
# those resolutions land: debugpy, delve, codelldb, netcoredbg, probe-rs,
# the VS Code JS/PHP debug adapters, elixir-ls, and moonwalk (Matt's Lua
# debugger, built from his repo when DIVER_MOONWALK_DIR points at it).
#
# Env:
#   DIVER_INSTALL_DAP   0 to skip (default 1)
#   DIVER_MOONWALK_DIR  moonwalk checkout (default ~/GH/Qompass/moonwalk)

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
# shellcheck source=../lib/toolchain.sh
source "$LIB_DIR/toolchain.sh"
diver_detect_platform

if [[ ${DIVER_INSTALL_DAP:-1} != 1 ]]; then
  diver_log "skipping DAP (DIVER_INSTALL_DAP=0)"
  exit 0
fi

if ((IS_NIX_ON_DROID)); then
  for pkg in delve lldb; do
    if ! diver_have "$pkg"; then
      diver_nix_install "nixpkgs#$pkg" || true
    fi
    diver_manifest_add "$pkg"
  done
  diver_ok "DAP step done (nix lane)"
  exit 0
fi

# --- debugpy (Python) ---
# uv tool install exposes the `debugpy` console script; DAP configs run it
# via `python -m debugpy --listen ... --wait-for-client`.
diver_uv_tool debugpy
if diver_have debugpy; then
  diver_log "debugpy adapter: $(command -v debugpy) -m debugpy"
fi

# --- delve (Go) ---
diver_go_pkg "github.com/go-delve/delve/cmd/dlv@latest" dlv

# --- codelldb (C/C++/Rust) ---
# VSIX carries the adapter at extension/adapter/codelldb.
if ! diver_have codelldb; then
  codelldb_url="$(_diver_gh_asset_url vadimcn/codelldb 'codelldb-.*-linux-x64\.vsix' 2>/dev/null || true)"
  if [[ -n $codelldb_url ]]; then
    if dest="$(diver_vsix "$codelldb_url" codelldb)"; then
      adapter="$(find "$dest" -path '*adapter/codelldb' -type f 2>/dev/null | head -1)"
      if [[ -n $adapter ]]; then
        chmod +x "$adapter"
        diver_link_bin "$adapter" codelldb
        diver_ok "codelldb adapter linked"
      else
        diver_warn "codelldb VSIX extracted but adapter/codelldb not found"
      fi
    fi
  else
    diver_warn "codelldb: no linux-x64 vsix in latest release"
  fi
fi
diver_manifest_add codelldb

# --- lldb-dap ---
# Ships inside LLVM distributions; the full LLVM build (scripts/lsp/clir_ls.sh)
# provides it. No standalone rootless distribution — report honestly.
if ! diver_have lldb-dap; then
  diver_warn "lldb-dap: ships with LLVM only (see scripts/lsp/clir_ls.sh) — skipped"
fi
diver_manifest_add lldb-dap

# --- netcoredbg (.NET) ---
if ! diver_have netcoredbg; then
  netcoredbg_url="$(_diver_gh_asset_url Samsung/netcoredbg 'netcoredbg-linux-amd64.*\.tar\.gz' 2>/dev/null || true)"
  if [[ -n $netcoredbg_url ]]; then
    nc_dest="$PREFIX/share/netcoredbg"
    if [[ ! -x $nc_dest/netcoredbg ]]; then
      diver_log "installing netcoredbg"
      diver_download_extract "$netcoredbg_url" "$nc_dest" || diver_warn "netcoredbg download failed"
      inner="$(find "$nc_dest" -name netcoredbg -type f 2>/dev/null | head -1)"
      [[ -n $inner ]] && diver_link_bin "$inner" netcoredbg
    fi
  else
    diver_warn "netcoredbg: no linux-amd64 tarball in latest release"
  fi
fi
diver_manifest_add netcoredbg

# --- vscode-js-debug (Node) ---
# Microsoft's JS debugger; the DAP server is dist/src/dapDebugServer.js.
if ! diver_have js-debug-adapter; then
  jsdbg_url="$(_diver_gh_asset_url microsoft/vscode-js-debug '\.vsix$' 2>/dev/null || true)"
  if [[ -n $jsdbg_url ]]; then
    if dest="$(diver_vsix "$jsdbg_url" vscode-js-debug)"; then
      server="$(find "$dest" -path '*dist/src/dapDebugServer.js' 2>/dev/null | head -1)"
      if [[ -n $server ]]; then
        printf '#!/usr/bin/env bash\nexec node "%s" "$@"\n' "$server" >"$BIN_DIR/js-debug-adapter"
        chmod +x "$BIN_DIR/js-debug-adapter"
        diver_ok "js-debug-adapter wrapper installed"
      else
        diver_warn "vscode-js-debug extracted but dapDebugServer.js not found"
      fi
    fi
  else
    diver_warn "vscode-js-debug: no vsix asset in latest release"
  fi
fi
diver_manifest_add js-debug-adapter

# --- php-debug-adapter (Xdebug VS Code extension) ---
if ! diver_have php-debug-adapter; then
  phpdbg_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/xdebug/vsextensions/vscode-php-debug/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
  if dest="$(diver_vsix "$phpdbg_url" vscode-php-debug)"; then
    ext="$(find "$dest/extension" -maxdepth 1 -type d -name 'extension*' 2>/dev/null | head -1)"
    server=""
    [[ -n $ext ]] && server="$(find "$ext" -name 'phpDebug.js' 2>/dev/null | head -1)"
    [[ -z $server ]] && server="$(find "$dest" -name 'phpDebug.js' 2>/dev/null | head -1)"
    if [[ -n $server ]]; then
      printf '#!/usr/bin/env bash\nexec node "%s" "$@"\n' "$server" >"$BIN_DIR/php-debug-adapter"
      chmod +x "$BIN_DIR/php-debug-adapter"
      diver_ok "php-debug-adapter wrapper installed"
    else
      diver_warn "vscode-php-debug extracted but phpDebug.js not found (check for extension/ prefix)"
    fi
  fi
fi
diver_manifest_add php-debug-adapter

# --- firefox-debug-adapter ---
diver_npm_global firefox-debug-adapter

# --- probe-rs (embedded) ---
diver_cargo_pkg probe-rs-tools probe-rs

# --- openocd (embedded) ---
# xPack publishes npm-wrapped openocd binaries.
if ! diver_have openocd; then
  if diver_have npm; then
    diver_log "installing @xpack-dev-tools/openocd (npm)"
    if npm install -g @xpack-dev-tools/openocd >/dev/null 2>&1; then
      xpack_bin="$(find "$(npm root -g)/@xpack-dev-tools/openocd" -name openocd -type f 2>/dev/null | head -1)"
      [[ -n $xpack_bin ]] && diver_link_bin "$xpack_bin" openocd
    else
      diver_warn "@xpack-dev-tools/openocd failed"
    fi
  else
    diver_warn "openocd: no npm — skipped"
  fi
fi
diver_manifest_add openocd

# --- elixir-ls (also a DAP server for Elixir) ---
if ! diver_have elixir-ls; then
  els_url="$(_diver_gh_asset_url elixir-lsp/elixir-ls '\.zip$' 2>/dev/null || true)"
  if [[ -n $els_url ]]; then
    els_dest="$PREFIX/share/elixir-ls"
    if [[ ! -f $els_dest/language_server.sh ]]; then
      diver_log "installing elixir-ls"
      diver_download_extract "$els_url" "$els_dest" || diver_warn "elixir-ls download failed"
    fi
    [[ -f $els_dest/language_server.sh ]] && diver_link_bin "$els_dest/language_server.sh" elixir-ls
  else
    diver_warn "elixir-ls: no zip in latest release"
  fi
fi
diver_manifest_add elixir-ls

# --- gdb (native) ---
if ! diver_have gdb; then
  diver_warn "gdb: system package — install via your distro (or pkg on Termux) — skipped"
fi
diver_manifest_add gdb

# --- moonwalk (Matt's Lua DAP debugger) ---
# Built from his checkout; DIVER_MOONWALK_DIR overrides the default guess.
MOONWALK_DIR="${DIVER_MOONWALK_DIR:-$HOME/GH/Qompass/moonwalk}"
if [[ -f $MOONWALK_DIR/lua/moonwalk/init.lua ]] || [[ -f $MOONWALK_DIR/README.md ]]; then
  diver_log "moonwalk checkout found at $MOONWALK_DIR"
  if [[ -f $MOONWALK_DIR/build.sh ]]; then
    (cd "$MOONWALK_DIR" && bash build.sh >/dev/null 2>&1) \
      && diver_ok "moonwalk built" || diver_warn "moonwalk build.sh failed"
  else
    diver_warn "moonwalk: no build.sh in $MOONWALK_DIR — build it manually"
  fi
else
  diver_warn "moonwalk: no checkout at $MOONWALK_DIR (set DIVER_MOONWALK_DIR) — skipped"
fi
diver_manifest_add moonwalk

diver_ok "DAP step done"
