-- /qompassai/Diver/lsp/ginko_ls.lua
-- Qompass AI Ginko LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/Schottkyc137/ginko
-- cargo install ginko
vim.api.nvim_create_autocmd
({
    'BufNewFile',
    'BufRead'
  },
  {
    pattern = {
      '*.dts',
      '*.dtsi'
    },
    callback = function(args)
      vim.bo[args.buf].filetype = 'devicetree'
    end,
  })
vim.lsp.config['ginko_ls'] {
  cmd = {
    'ginko_ls'
  },
  filetypes = {
    'devicetree',
    'dts'
  },
  root_markers = {
    '.git'
  },
  settings = {
    provideFormatter = false
  },
}