#!/bin/bash
# /qompassai/Diver/scripts/diver.sh
# ----------------------------------------
# Copyright (C) 2025 Qompass AI, All rights reserved

DIVER_DIR="$HOME/.diver"
REPO_DIR="$(pwd)"
CONFIG_FILES=(
  .editorconfig .envrc .cbfmt.toml init.lua .luacheckrc .lua-format .luarc.json .markdownlint.yaml .marksman.toml .neoconf.json .prettierrc pyrightconfig.json selene.toml stylua.toml vim.toml vim.yml
)

mkdir -p "$DIVER_DIR"
mkdir -p "$HOME/.diver/nvim"

echo "Copying configuration files to $DIVER_DIR:"
for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$REPO_DIR/$file" ]; then
    cp -v "$REPO_DIR/$file" "$DIVER_DIR/$file"
  else
    echo "  ! Warning: $file not found in repo"
  fi
done

ln -sfv "$DIVER_DIR/init.lua" "$HOME/.config/nvim/init.lua"
add_to_bashrc() {
  if ! grep -qF "$1" "$HOME/.bashrc"; then
    echo "$1" >>"$HOME/.bashrc"
  fi
}

add_to_bashrc "export DIVER_ROOT=\"$DIVER_DIR\""
cat <<'EOF' >"$HOME/.local/bin/diver"
#!/bin/bash
NVIM_APPNAME=diver nvim "$@"
EOF
chmod +x "$HOME/.local/bin/diver"

echo "Diver setup complete. Restart your terminal or run:"
echo "source ~/.bashrc"
