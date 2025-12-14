-- /qompassai/Diver/lsp/millet_ls.lua
-- Qompass AI Millet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/azdavis/millet
-- cargo install --git https://github.com/azdavis/millet millet-ls --bin millet-ls
-- cargo install --git https://github.com/azdavis/millet millet-cli --bin millet-cli
-- cargo install --git https://github.com/azdavis/millet xtask --bin xtask
vim.lsp.config['millet_ls'] = {
  cmd = {
    'millet',
  },
  filetypes = {
    'sml',
  },
  root_markers = {
    'millet.toml',
  },
}