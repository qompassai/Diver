#!/usr/bin/env bash
# #################################################################
# /qompassai/scripts/arch/arch_lsp.sh
# Qompass AI Arch Lsp
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
set -euo pipefail
LSP_LIST_FILE="lsp.txt"
if [[ ! -f "$LSP_LIST_FILE" ]]; then
  echo "ERROR: $LSP_LIST_FILE not found in current directory."
  exit 1
fi
have() { command -v "$1" &>/dev/null; }
AUR_HELPER=""
if have paru; then
  AUR_HELPER="paru"
elif have yay; then
  AUR_HELPER="yay"
fi
install_pacman() {
  local pkg="$1"
  echo "==> Installing (pacman): $pkg"
  sudo pacman --noconfirm --needed -S "$pkg"
}
install_aur() {
  local pkg="$1"
  if [[ -z "$AUR_HELPER" ]]; then
    echo "!! AUR helper not found, install $pkg manually."
    return
  fi
  echo "==> Installing (AUR via $AUR_HELPER): $pkg"
  "$AUR_HELPER" --noconfirm --needed -S "$pkg"
}
install_npm() {
  local pkg="$1"
  echo "==> Installing (npm): $pkg"
  npm install -g "$pkg"
}
install_pip() {
  local pkg="$1"
  echo "==> Installing (pip): $pkg"
  pip install --user "$pkg"
}
install_cargo() {
  local pkg="$1"
  echo "==> Installing (cargo): $pkg"
  cargo install "$pkg"
}
install_lsp() {
  local name="$1"
  case "$name" in
    clangd_ls.lua)
      install_pacman "clang"
      ;;
    lua_ls.lua)
      install_pacman "lua-language-server"
      ;;
    bash_ls.lua)
      # bash-language-server via npm
      install_npm "bash-language-server"
      ;;
    json_ls.lua)
      # vscode-langservers-extracted (JSON, HTML, CSS)
      install_npm "vscode-langservers-extracted"
      ;;
    html_ls.lua)
      install_npm "vscode-langservers-extracted"
      ;;
    css_ls.lua)
      install_npm "vscode-langservers-extracted"
      ;;
    ts_ls.lua|tsserver.lua|tsgo_ls.lua)
      # typescript-language-server
      install_npm "typescript"    # compiler
      install_npm "typescript-language-server"
      ;;
    svelte_ls.lua)
      install_npm "svelte-language-server"
      ;;
    tailwindcss_ls.lua)
      install_npm "@tailwindcss/language-server"
      ;;
    yaml_ls.lua)
      install_npm "yaml-language-server"
      ;;
    docker_ls.lua)
      install_npm "dockerfile-language-server-nodejs"
      ;;

    terraform_ls.lua)
      # terraform-ls binary via AUR
      install_aur "terraform-ls-bin"
      ;;

    texlab_ls.lua)
      install_pacman "texlab"
      ;;

    pyright_ls.lua|pyrefly_ls.lua)
      install_npm "pyright"
      ;;

    rustana_ls.lua|rust_analyzer.lua|rust_ls.lua)
      install_pacman "rust-analyzer"
      ;;

    gop_ls.lua|go_ls.lua|golangcilint_ls.lua)
      install_pacman "gopls"
      install_pacman "golangci-lint"
      ;;

    omnisharp_ls.lua|csharp_ls.lua)
      install_aur "omnisharp-roslyn-bin"
      ;;

    prisma_ls.lua)
      install_npm "prisma-language-server"
      ;;

    graphql_ls.lua)
      install_npm "graphql-language-service-cli"
      ;;

    eslint_ls.lua)
      install_npm "eslint"
      ;;

    styleable_ls.lua|stylua_ls.lua|stylua3p_ls.lua)
      install_pacman "stylua"
      ;;

    taplo_ls.lua)
      install_pacman "taplo"
      ;;

    markdownoxide_ls.lua|marksman_ls.lua)
      install_pacman "marksman"
      ;;

    vim_ls.lua|vimdoc_ls.lua)
      # vim-language-server via npm
      install_npm "vim-language-server"
      ;;

    vue_ls.lua)
      install_npm "@vue/language-server"
      ;;

    yaml_ls.lua)
      install_npm "yaml-language-server"
      ;;
    apex_ls.lua|soql_ls.lua|lwc_ls.lua|visualforce_ls.lua)
      echo "!! Salesforce LSPs usually use sfdx plugins or dedicated binaries."
      echo "   Install via Salesforce DX / code extensions as needed."
      ;;
    *)
      echo "?? No install mapping for $name, skipping."
      ;;
  esac
}
echo "Reading LSP list from $LSP_LIST_FILE..."
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  lsp_name="$line"
  echo "Processing $lsp_name..."
  install_lsp "$lsp_name"
done < "$LSP_LIST_FILE"
echo "Done."
