#!/bin/sh
# qompassai/Diver/scripts/quickstart.sh
# Qompass AI Diver uick‑Start
# Copyright (C) 2025 Qompass AI, All rights reserved
# --------------------------------------------------
set -eu
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DIVER_DIR="$XDG_DATA_HOME/diver"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_VERSION="${PYTHON_VERSION:-3.13}"
VENV_PATH="$DIVER_DIR/.python/.venv${PYTHON_VERSION%.*}${PYTHON_VERSION#*.}"
PYTHON_BIN="python$PYTHON_VERSION"
VENV_PY="$VENV_PATH/bin/python$PYTHON_VERSION"
CONFIG_FILES="
.editorconfig
.envrc
.cbfmt.toml
init.lua
.luacheckrc
.lua-format
.luarc.json
.markdownlint.yaml
.marksman.toml
selene.toml
stylua.toml
vim.toml
vim.yml
"
detect_os() {
  case "$(uname -s)" in
  Darwin*) OS="macos" ;;
  Linux*) OS="linux" ;;
  FreeBSD*) OS="bsd" ;;
  CYGWIN* | MINGW* | MSYS*) OS="windows" ;;
  *) OS="unknown" ;;
  esac
}
find_python() {
  if [ -n "${PYTHON_PATH:-}" ] && command -v "$PYTHON_PATH" >/dev/null 2>&1; then
    PYTHON_EXE="$PYTHON_PATH"
    return 0
  fi
  if command -v pyenv >/dev/null 2>&1; then
    py_path="$(pyenv root)/versions/$PYTHON_VERSION/bin/python$PYTHON_VERSION"
    if [ -x "$py_path" ]; then
      PYTHON_EXE="$py_path"
      return 0
    fi
  fi
  if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    PYTHON_EXE="$(command -v "$PYTHON_BIN")"
    return 0
  fi
  # Fallback: python3
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_EXE="$(command -v python3)"
    return 0
  fi
  echo "❌ Cannot find a suitable Python ($PYTHON_BIN)" >&2
  exit 1
}
echo "Setting up Python virtual environment..."
mkdir -p "$DIVER_DIR/.python"
find_python
if [ ! -d "$VENV_PATH" ]; then
  "$PYTHON_EXE" -m venv "$VENV_PATH"
  "$VENV_PATH/bin/pip" install --upgrade pip pynvim
  echo "Created Python venv at $VENV_PATH"
else
  echo "Python venv already exists at $VENV_PATH"
fi
echo "\nCopying Diver configuration files..."
mkdir -p "$DIVER_DIR/nvim"
for file in $CONFIG_FILES; do
  if [ -f "$REPO_DIR/$file" ]; then
    cp -v "$REPO_DIR/$file" "$DIVER_DIR/$file"
  else
    echo "  ! Warning: $file not found in repo"
  fi
done

echo "\nLinking Diver config..."
mkdir -p "$XDG_CONFIG_HOME/nvim"
ln -sf "$DIVER_DIR/init.lua" "$XDG_CONFIG_HOME/nvim/init.lua"
echo "\nConfiguring Diver Python integration..."
PYTHON_CONFIG_LINE="vim.g.python3_host_prog = '$VENV_PATH/bin/python'"
if grep -q 'python3_host_prog' "$DIVER_DIR/init.lua" 2>/dev/null; then
  # In-place edit (POSIX version)
  TMPF="$DIVER_DIR/init.lua.tmp"
  sed "s|vim.g.python3_host_prog.*|$PYTHON_CONFIG_LINE|" "$DIVER_DIR/init.lua" >"$TMPF"
  mv "$TMPF" "$DIVER_DIR/init.lua"
  echo "Updated Python path in init.lua"
else
  echo "$PYTHON_CONFIG_LINE" >>"$DIVER_DIR/init.lua"
  echo "Added Python path to init.lua"
fi
echo "\nUpdating shell rc files..."
add_to_rc() {
  rc_file="$1"
  line="$2"
  if [ -f "$rc_file" ] && ! grep -Fq "$line" "$rc_file"; then
    printf '\n# Added by Python quickstart\n%s\n' "$line" >>"$rc_file"
    echo " → $rc_file updated"
  fi
}
add_to_rc "$HOME/.bashrc" "export PATH=\"$VENV_PATH/bin:\$PATH\""
add_to_rc "$HOME/.bashrc" "export EDITOR=nvim"
add_to_rc "$HOME/.bashrc" "alias vim=nvim"
add_to_rc "$HOME/.zshrc" "export PATH=\"$VENV_PATH/bin:\$PATH\""
add_to_rc "$HOME/.zshrc" "export EDITOR=nvim"
add_to_rc "$HOME/.zshrc" "alias vim=nvim"
echo "\nSetup complete! 🚀"
echo "Python venv: $VENV_PATH"
echo "Diver config: $DIVER_DIR"
