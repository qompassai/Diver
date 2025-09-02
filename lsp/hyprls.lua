-- /qompassai/Diver/lsp/hyprls.lua
-- Qompass AI HyprLS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['hyprls'] = {
  cmd = { 'hyprls' },
  filetypes = { 'hyprlang', 'hypr' },
  single_file_support = true,
  settings = {
    hyprls = {
      completion = {
        enable = true,
        keywordSnippet = "Disable",
      },
      telemetry = {
        enable = false,
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
}

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    pattern = { "*.hl", "hypr*.conf" },
    callback = function(event)
        vim.notify("starting hyprls for " .. vim.inspect(event))
        vim.lsp.start {
            name = "hyprlang",
            cmd = { "hyprls" },
            root_dir = vim.fn.getcwd(),
        }
    end
})