-- /qompassai/Diver/lsp/zls.lua
-- Qompass AI ZLS LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config["zls"] = {
  cmd = { "zls" },
  filetypes = { "zig", "zon", "ziggy", "zine" },
  settings = {
    zls = {
      enable_ast_check_diagnostics = true,
      enable_build_on_save = true,
      enable_inlay_hints = true,
      inlay_hints = {
        parameter_names = true,
        variable_names = true,
        builtin = true,
        type_names = true,
      },
    },
  },
}
