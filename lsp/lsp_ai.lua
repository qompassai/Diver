-- /qompassai/Diver/lsp/lsp-ai.lua
-- Qompass AI Qompass LSP-AI Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

return {
  cmd = { "lsp-ai" },
  filetypes = {},
  -- root_dir = nil,
  init_options = {
    memory = {
      file_store = vim.empty_dict(),
    },
    models = vim.empty_dict(),
  },
}
