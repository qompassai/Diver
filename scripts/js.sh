#!/usr/bin/env bash
# /qompassai/Diver/lsp/js.sh
# Qompass AI Diver LSP JS Script
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
set -euo pipefail
pnpm add -g \
  @abaplint/cli@latest \
  @abaplint/transpiler-cli@latest \
  @abaplint/transpiler@latest \
  @abaplint/runtime@latest
  @angular/language-server@latest \
  @awk-language-server@latest \
  @azure-pipelines-language-server@latest \
  @css-variables-language-server@latest \
  @cssmodules-language-server@latest \
  @cucumber/language-server@latest \
  @custom-elements-languageserver@latest \
  git+https://github.com/salesforce-misc/bazelrc-lsp.git \
  @herb-tools/language-server@latest \
  @imc-trading/svlangserver@latest \
  @lean-language-server@latest \
  @microsoft/compose-language-service@latest \
  @neo4j-cypher/language-server@latest \
  @oxlint@latest \
  @perlnavigator-server@latest \
  @quick-lint-js@latest
  @rescript/language-server@latest \
  @sap/cds-lsp@latest \
  @shopify/cli@latest \
  @solc@latest \
  @solidity-ls@latest \
  @stimulus-language-server@latest \
  @stylable/language-service@latest \
  @stylelint-lsp@latest \
  @svelte-language-server@latest \
  @tailwindcss/language-server@latest \
  @typescript-language-server@latest \
  typescript@latest \
  @typespec/compiler@latest \
  @urbit/hoon-language-server@latest \
  @vim-language-server@latest \
  @vlabo/cspell-lsp@latest \
  @vscode-langservers-extracted@latest \
  @vue/language-server@latest \
  @yaml-language-server@latest