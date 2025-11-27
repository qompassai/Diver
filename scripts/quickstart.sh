#!/usr/bin/env bash
# qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver QuickStart
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
set -euo pipefail
detect_os() {
  case "$(uname -s)" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      echo "wsl"
    elif [ -n "${ANDROID_ROOT-}" ] || [ -n "${TERMUX_VERSION-}" ]; then
      echo "android"
    else
      echo "linux"
    fi
    ;;
  Darwin) echo "macos" ;;
  CYGWIN* | MINGW* | MSYS* | MINGW64_NT*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}
install_neovim() {
  local os="$1"
  echo "Installing Neovim for $os"
  case "$os" in
  linux | wsl)
    if command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --needed --noconfirm neovim
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y neovim
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y neovim
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper install -y neovim
    else
      echo "No known package manager found; install Neovim manually."
    fi
    ;;
  macos)
    if command -v brew >/dev/null 2>&1; then
      brew install neovim
    else
      echo "Homebrew not found; install Neovim manually."
    fi
    ;;
  android)
    if command -v pkg >/dev/null 2>&1; then
      pkg install -y neovim
    else
      echo "No known Android package manager found; install Neovim manually."
    fi
    ;;
  windows)
    echo "On Windows, install Neovim via winget/choco/scoop or the official installer."
    ;;
  *)
    echo "Unknown OS; skipping Neovim installation."
    ;;
  esac
}
install_bob() {
  echo "Installing bob (Neovim version manager) via Cargo"
  if command -v cargo >/dev/null 2>&1; then
    cargo install bob-nvim || echo "Failed to install bob-nvim (continuing)"
  else
    echo "cargo not found; skipping bob install"
  fi
}
append_if_missing() {
  local file="$1"
  local line="$2"
  [ -f "$file" ] || touch "$file"
  if ! grep -qF "$line" "$file"; then
    echo "$line" >>"$file"
    echo "Added to $(basename "$file"): $line"
  else
    echo "Already in $(basename "$file"): $line"
  fi
}
validate_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "%-18s: " "$name"
    "$cmd" --version 2>/dev/null | head -n1 || echo "ok"
    echo "  path: $(command -v "$cmd")"
  else
    echo "$name: NOT FOUND"
  fi
}
OS_ID="$(detect_os)"
install_neovim "$OS_ID"
install_bob
DIVER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/diver"
REPO_DIR="$(dirname "$(realpath "$0")")"
CONFIG_FILES=(
  .editorconfig .envrc .cbfmt.toml init.lua .luacheckrc .lua-format
  .luarc.json .markdownlint.yaml .marksman.toml .neoconf.json .prettierrc
  pyrightconfig.json selene.toml stylua.toml vim.toml vim.yml
)
mkdir -p "$DIVER_DIR/nvim"
for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$REPO_DIR/$file" ]; then
    cp -v "$REPO_DIR/$file" "$DIVER_DIR/$file"
  else
    echo "  ! Warning: $file not found in repo"
  fi
done
echo -e "\nLinking Diver to Neovim configuration"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
ln -sfv "$DIVER_DIR/init.lua" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim/init.lua"
PYTHON_CONFIG_LINE="vim.g.python3_host_prog = '${VENV_PATH:-$HOME/.venv}/bin/python'"
if grep -q "python3_host_prog" "$DIVER_DIR/init.lua"; then
  sed -i "s|vim.g.python3_host_prog.*|$PYTHON_CONFIG_LINE|" "$DIVER_DIR/init.lua"
  echo "Updated Python path in init.lua"
else
  echo "$PYTHON_CONFIG_LINE" >>"$DIVER_DIR/init.lua"
  echo "Added Python path to init.lua"
fi
BASHRC="$HOME/.bashrc"
append_if_missing "$BASHRC" "export PATH=\"${VENV_PATH:-$HOME/.venv}/bin:\$PATH\""
append_if_missing "$BASHRC" "export EDITOR=nvim"
append_if_missing "$BASHRC" "alias vim=nvim"
append_if_missing "$BASHRC" "alias luarocks='luarocks --lua-version=5.1'"
ZSHRC="$HOME/.zshrc"
append_if_missing "$ZSHRC" "export PATH=\"${VENV_PATH:-$HOME/.venv}/bin:\$PATH\""
append_if_missing "$ZSHRC" "export EDITOR=nvim"
append_if_missing "$ZSHRC" "alias vim=nvim"
append_if_missing "$ZSHRC" "alias luarocks='luarocks --lua-version=5.1'"
FISH_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d"
mkdir -p "$FISH_CONF_DIR"
FISH_FILE="$FISH_CONF_DIR/diver-nvim.fish"
if [ ! -f "$FISH_FILE" ]; then
  cat >"$FISH_FILE" <<'EOF'
set -gx PATH "$VENV_PATH/bin" $PATH
set -gx EDITOR nvim
alias vim nvim
alias luarocks "luarocks --lua-version=5.1"
EOF
  echo "Created $FISH_FILE"
fi
LUAROCKS_TREE="$HOME/.luarocks"
mkdir -p "$LUAROCKS_TREE"
LUAROCKS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/luarocks"
LUAROCKS_CONFIG_FILE="$LUAROCKS_CONFIG_DIR/config-5.1.lua"
mkdir -p "$LUAROCKS_CONFIG_DIR"
cat >"$LUAROCKS_CONFIG_FILE" <<EOF
rocks_trees = {
  { name = [[user]], root = [[${LUAROCKS_TREE}]] }
}
lua_interpreter = [[lua5.1]]
EOF
ROCKS=(
  emmyluacodestyle
  fzf-lua
  image_handler
  luacheck
  luafilesystem
  lua-language-server
  luasocket
  lua-cjson
  luv
  magick
)
echo "Installing LuaRocks (Lua 5.1/User-Space) for Neovim"
for rock in "${ROCKS[@]}"; do
  echo "  -> luarocks install $rock"
  if ! luarocks --lua-version=5.1 install "$rock" --local --force-lock; then
    echo "  ! Failed to install $rock (continuing)"
  fi
done
echo
echo "Validation:"
validate_cmd "neovim" nvim
validate_cmd "bob-nvim" bob
validate_cmd "lua51" lua5.1
validate_cmd "luarocks" luarocks
if command -v "${VENV_PATH:-$HOME/.venv}/bin/python" >/dev/null 2>&1; then
  printf "%-18s: " "python3_host_prog"
  "${VENV_PATH:-$HOME/.venv}/bin/python" -V 2>&1 || true
  echo "  path: ${VENV_PATH:-$HOME/.venv}/bin/python"
fi
if command -v pip3 >/dev/null 2>&1; then
  printf "%-18s: " "pynvim (pip3)"
  pip3 show pynvim 2>/dev/null | awk '/Version/ {print $0}' || echo "not installed"
fi
if command -v npm >/dev/null 2>&1; then
  printf "%-18s: " "neovim (npm)"
  npm list -g neovim 2>/dev/null | head -n1 || echo "not installed"
fi
if command -v gem >/dev/null 2>&1; then
  printf "%-18s: " "neovim (gem)"
  gem list neovim -i >/dev/null 2>&1 && gem list neovim | head -n1 || echo "not installed"
fi
if command -v cpanm >/dev/null 2>&1; then
  printf "%-18s: " "Neovim::Ext"
  cpanm --info Neovim::Ext 2>/dev/null | head -n1 || echo "check manually"
fi
echo
echo "Neovim config: $DIVER_DIR"
echo "LuaRocks tree: $LUAROCKS_TREE (Lua 5.1, local by default)"
