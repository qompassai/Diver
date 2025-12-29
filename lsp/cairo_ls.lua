-- /qompassai/Diver/lsp/cairo_ls.lua
-- Qompass AI Cairo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'scarb',
    'cairo-language-server',
    '/C',
    '--node-ipc',
  },
  init_options = {
    hostInfo = 'neovim',
  },
  filetypes = {
    'cairo',
  },
  root_markers = {
    'Scarb.toml',
    'cairo_project.toml',
    '.git',
  },
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'cairo',
    callback = function()
      vim.lsp.start({
        name = 'cairo_ls',
        cmd = {
          'scarb',
          'cairo-language-server',
          '/C',
          '--node-ipc',
        },
        root_dir = vim.fs.dirname(vim.fs.find({
          'Scarb.toml',
          'cairo_project.toml',
          '.git',
        })[1]),
      })
    end,
  }),
}