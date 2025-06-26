#!/bin/bash
DIVER_DIR="$HOME/.diver"
REPO_DIR="$(dirname "$(realpath "$0")")"
PYTHON_BIN="$HOME/.pyenv/versions/3.13.5/bin/python3.13"
VENV_PATH="$DIVER_DIR/.python/.venv313"
echo "Creating language directories..."
mkdir -p "$DIVER_DIR/.go"
mkdir -p "$DIVER_DIR/.js"
mkdir -p "$DIVER_DIR/.lua"
mkdir -p "$DIVER_DIR/.markdown"
mkdir -p "$DIVER_DIR/.mojo"
mkdir -p "$DIVER_DIR/.python"
mkdir -p "$DIVER_DIR/.zig"
echo "Setting up Python virtual environment..."
if [ ! -d "$VENV313" ]; then
  "$PYTHON_BIN" -m venv "$VENV_PATH"
  "$VENV_PATH/bin/pip" install --upgrade pip pynvim
  echo "Created Python venv at $VENV_PATH"
else
  echo "Python venv already exists at $VENV_PATH"
fi
CONFIG_FILES=(
  .editorconfig .envrc .cbfmt.toml init.lua .luacheckrc .lua-format
  .luarc.json .markdownlint.yaml .marksman.toml .neoconf.json .prettierrc
  pyrightconfig.json selene.toml stylua.toml vim.toml vim.yml
)
echo -e "\nCopying Neovim configuration files..."
mkdir -p "$DIVER_DIR/nvim"
for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$REPO_DIR/$file" ]; then
    cp -v "$REPO_DIR/$file" "$DIVER_DIR/$file"
  else
    echo "  ! Warning: $file not found in repo"
  fi
done
echo -e "\nCopying nested language config files..."
for lang in .js .lua; do
  if [ -d "$REPO_DIR/$lang" ]; then
    rsync -av --exclude='.git' --exclude='.DS_Store' "$REPO_DIR/$lang/" "$DIVER_DIR/$lang/"
  else
    echo "  ! Warning: $lang directory not found in repo"
  fi
done
echo -e "\nLinking Neovim configuration..."
mkdir -p "$HOME/.config/nvim"
ln -sfv "$DIVER_DIR/init.lua" "$HOME/.config/nvim/init.lua"
PYTHON_CONFIG_LINE="vim.g.python3_host_prog = '$VENV313/bin/python'"
if grep -q "python3_host_prog" "$DIVER_DIR/init.lua"; then
  sed -i "s|vim.g.python3_host_prog.*|$PYTHON_CONFIG_LINE|" "$DIVER_DIR/init.lua"
  echo "Updated Python path in init.lua"
else
  echo "$PYTHON3_CONFIG_LINE" >>"$DIVER_DIR/init.lua"
  echo "Added Python path to init.lua"
fi
add_to_bashrc() {
  if ! grep -qF "$1" "$HOME/.bashrc"; then
    echo "$1" >>"$HOME/.bashrc"
    echo "Added to bashrc: $1"
  else
    echo "Already in bashrc: $1"
  fi
}
add_to_bashrc "export PATH=\"$VENV313/bin:\$PATH\""
add_to_bashrc "export EDITOR=nvim"
add_to_bashrc "alias vim=nvim"
echo -e "\nSetup complete! 🚀"
echo "Python venv: $VENV_PATH"
echo "Neovim config: $DIVER_DIR"
