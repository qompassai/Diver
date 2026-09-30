#!/usr/bin/env bash
# steps/95-hosts.sh — Neovim remote-plugin providers (node/python/ruby).
#
# Installs the `neovim` client packages user-locally so :checkhealth
# providers go green. Also installs the lua-language-server binary
# (prebuilt upstream release) plus the `lua_ls` shim the config expects.
#
# All user-local. Best-effort per provider — a missing package manager
# only skips its provider.

set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)"
# shellcheck source=../lib/common.sh
source "$LIB_DIR/common.sh"
diver_detect_platform

# --- node provider ---
if diver_have pnpm; then
  pnpm add -g neovim >/dev/null 2>&1 && diver_log "node provider: pnpm neovim ok" \
    || diver_warn "node provider: pnpm add -g neovim failed"
elif diver_have npm; then
  # npm -g is rootless only when the prefix is user-owned; try, tolerate failure.
  npm install -g neovim >/dev/null 2>&1 && diver_log "node provider: npm neovim ok" \
    || diver_warn "node provider: npm install -g neovim failed (check npm prefix)"
else
  diver_warn "node provider skipped: no pnpm/npm"
fi

# --- python provider ---
# pynvim is a library, not a CLI app — `uv tool install` would build a venv
# whose console script does nothing useful. Use a dedicated venv under the
# Diver data dir and make sure its python is what Neovim finds.
PYNVIM_VENV="$XDG_DATA_HOME/diver/venvs/pynvim"
if diver_have uv; then
  if [[ ! -x $PYNVIM_VENV/bin/python ]]; then
    uv venv "$PYNVIM_VENV" >/dev/null 2>&1 \
      && VIRTUAL_ENV="$PYNVIM_VENV" uv pip install pynvim >/dev/null 2>&1 \
      && diver_log "python provider: uv venv pynvim ok" \
      || diver_warn "python provider: uv venv/pip install pynvim failed"
  fi
  if [[ -x $PYNVIM_VENV/bin/python ]] && "$PYNVIM_VENV/bin/python" -c "import pynvim" 2>/dev/null; then
    diver_log "python provider: pynvim importable at $PYNVIM_VENV/bin/python"
    # Neovim's python3 provider host: point it at this venv's python.
    diver_link_bin "$PYNVIM_VENV/bin/python" diver-pynvim-python || true
  fi
elif diver_have pip3; then
  pip3 install --user pynvim >/dev/null 2>&1 && diver_log "python provider: pip pynvim ok" \
    || diver_warn "python provider: pip install pynvim failed"
elif diver_have pip; then
  pip install --user pynvim >/dev/null 2>&1 && diver_log "python provider: pip pynvim ok" \
    || diver_warn "python provider: pip install pynvim failed"
else
  diver_warn "python provider skipped: no uv/pip"
fi

# --- ruby provider ---
if diver_have gem; then
  gem install --user-install neovim >/dev/null 2>&1 && diver_log "ruby provider: gem neovim ok" \
    || diver_warn "ruby provider: gem install neovim failed"
else
  diver_warn "ruby provider skipped: no gem"
fi

# --- lua-language-server (prebuilt binary; replaces the old luarocks build) ---
install_lua_ls() {
  if ((IS_NIX_ON_DROID)); then
    diver_nix_install nixpkgs#lua-language-server || {
      diver_warn "lua-language-server unavailable via nix"
      return 0
    }
  elif ((IS_TERMUX)); then
    pkg install -y lua-language-server 2>/dev/null || true
    diver_have lua-language-server || {
      diver_warn "lua-language-server unavailable on Termux"
      return 0
    }
  else
    local ver="3.15.0"
    local arch="$DIVER_ARCH"
    [[ $arch == "aarch64" ]] && arch="arm64"
    local url="https://github.com/LuaLS/lua-language-server/releases/download/${ver}/lua-language-server-${ver}-${DIVER_OS}-${arch}.tar.gz"
    local dest="$PREFIX/lua-language-server-${ver}"
    if [[ ! -x $dest/bin/lua-language-server ]]; then
      diver_log "installing lua-language-server $ver → $dest"
      diver_download_extract "$url" "$dest" || {
        diver_warn "lua-language-server download failed"
        return 0
      }
    fi
    diver_link_bin "$dest/bin/lua-language-server" lua-language-server
  fi

  # The config's lsp/lua_ls.lua expects a `lua_ls` command.
  cat >"$BIN_DIR/lua_ls" <<'EOF'
#!/usr/bin/env bash
exec lua-language-server "$@"
EOF
  chmod +x "$BIN_DIR/lua_ls"
  diver_log "lua-language-server: $(lua-language-server --version 2>/dev/null | head -1)"
}
install_lua_ls

diver_ok "providers step done"
