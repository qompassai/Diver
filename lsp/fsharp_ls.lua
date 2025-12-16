-- /qompassai/Diver/lsp/fsharp_ls.lua
-- Qompass AI F# LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.api.nvim_create_autocmd({
  'BufNewFile',
  'BufRead',
}, {
  pattern = {
    '*.fs',
    '*.fsx',
    '*.fsi'
  },
  callback = function(args)
    vim.bo[args.buf].filetype = 'fsharp'
  end,
})
---@type vim.lsp.Config
return {
  cmd = {
    'dotnet',
    'FSharpLanguageServer.dll',
  },
  filetypes = {
    'fsharp',
  },
  root_markers = {
    '*.sln',
    '*.fsproj',
    '.git',
  },
  init_options = {
    AutomaticWorkspaceInit = true,
  },
  settings = {},
}