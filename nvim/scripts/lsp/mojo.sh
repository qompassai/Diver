#!/usr/bin/env bash
# /qompassai/diver/scripts/mojo.sh
# Qompass AI Diver Mojo Setup Script
# Copyright (C) 2026 Qompass AI, All rights reserved
####################################################
set -euo pipefail
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
install_pixi()
{
  if command -v pixi > /dev/null 2>&1; then
    echo "pixi already installed at: $(command -v pixi)"
    return
  fi
  if ! command -v cargo > /dev/null 2>&1; then
    echo "Error: cargo not found in PATH. Please install Rust/cargo first." >&2
    exit 1
  fi
  cargo install pixi
}
configure_pixi()
{
  local pixi_config_dir="$XDG_CONFIG_HOME/pixi"
  local pixi_config_file="$pixi_config_dir/config.toml"
  mkdir -p "$pixi_config_dir"
  if [ ! -f "$pixi_config_file" ]; then
    cat > "$pixi_config_file" << 'EOF'
# Reference: https://prefix-dev.github.io/pixi/
default-channels = ["conda-forge"]
change-ps1 = true
tls-no-verify = false
[pypi-config]
index-url = "https://pypi.org/simple"
extra-index-urls = []
keyring-provider = "subprocess"
EOF
    echo "Created pixi config: $pixi_config_file"
  else
    echo "pixi config already exists: $pixi_config_file"
  fi
  local pixi_manifest_dir="$XDG_CONFIG_HOME/pixi/manifests"
  mkdir -p "$pixi_manifest_dir"
}
link_mojo_tools()
{
  local mojo_env_dir="$XDG_DATA_HOME/mojo/.pixi/envs/default"
  local mojo_bin_dir="$mojo_env_dir/bin"
  local user_bin_dir="$HOME/.local/bin"
  mkdir -p "$user_bin_dir"
  if [ ! -x "$mojo_bin_dir/mojo-lsp-server" ]; then
    echo "Warning: $mojo_bin_dir/mojo-lsp-server not found or not executable." >&2
  else
    ln -sf "$mojo_bin_dir/mojo-lsp-server" "$user_bin_dir/mojo-lsp-server"
    echo "Linked mojo-lsp-server -> $user_bin_dir/mojo-lsp-server"
  fi
  if [ ! -x "$mojo_bin_dir/mojo-lldb-dap" ]; then
    echo "Warning: $mojo_bin_dir/mojo-lldb-dap not found or not executable." >&2
  else
    ln -sf "$mojo_bin_dir/mojo-lldb-dap" "$user_bin_dir/mojo-lldb-dap"
    echo "Linked mojo-lldb-dap -> $user_bin_dir/mojo-lldb-dap"
  fi
}
main()
{
  install_pixi
  configure_pixi
  link_mojo_tools
}
main "$@"
