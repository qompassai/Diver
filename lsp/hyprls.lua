-- /qompassai/Diver/lsp/hyprls.lua
-- Qompass AI HyprLS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- go install github.com/hyprland-community/hyprls/cmd/hyprls@latest
vim.lsp.config['hyprls'] = {
  cmd = { 'hyprls' },
  filetypes = { 'hyprlang', 'hypr' },
  single_file_support = true,
  settings = {
    hyprls = {
      colorProvider = {
        enable = true
      },
      completion = {
        enable = true,
        keywordSnippet = "Enable",
      },
      diagnostics = {
        enable = true
      },
      documentSymbol = {
        enable = true
      },
      formatting = {
        enable = true
      },
      hover = {
        enable = true
      },
      preferIgnoreFile = true,
      semanticTokens = {
        enable = true
      },
      telemetry = {
        enable = false
      },
    },
  },
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    pattern = { "*.hl", "hypr*.conf" },
    callback = function(event)
      print(string.format("starting hyprls for %s", vim.inspect(event)))
      vim.lsp.start {
        name = "hyprlang",
        cmd = { "hyprls" },
        root_dir = vim.fn.getcwd(),
        settings = {
          hyprls = {
            preferIgnoreFile = true,
            ignore = { "hyprlock.conf", "hypridle.conf" }
          }
        }
      }
    end
  })
}