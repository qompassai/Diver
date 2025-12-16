#!/usr/bin/env bash
# /qompassai/Diver/lsp/js.sh
# Qompass AI Diver LSP JS Script
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
set -euo pipefail
pnpm add -g \
  @angular/language-server@latest \
  awk-language-server@latest \
  @cucumber/language-server@latest \
  @herb-tools/language-server@latest \
  @imc-trading/svlangserver@latest \
  @neo4j-cypher/language-server@latest \
  @rescript/language-server@latest \
  @sap/cds-lsp@latest \
  azure-pipelines-language-server@latest \
  css-variables-language-server@latest \
  cssmodules-language-server@latest \
  custom-elements-languageserver@latest \
  lean-language-server@latest \
  git+https://github.com/salesforce-misc/bazelrc-lsp.git \
  solc@latest \
  solidity-ls@latest \
  stimulus-language-server@latest \
  stylelint-lsp@latest \
  svelte-language-server@latest \
  @tailwindcss/language-server@latest \
  typescript-language-server@latest \
  typescript@latest \
  @typespec/compiler@latest \
  @urbit/hoon-language-server@latest \
  vim-language-server@latest \
  vscode-langservers-extracted@latest \
  @vue/language-server@latest \
  yaml-language-server@latest
