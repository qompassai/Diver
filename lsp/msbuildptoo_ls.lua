-- /qompassai/Diver/lsp/msbuild_project_tools_server.lua
-- Qompass AI MSBuild LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
-- References:  https://github.com/qompassai/dotnet/scripts/quickstart.sh
vim.filetype.add(
  {
    extension = {
      props = 'msbuild',
      tasks = 'msbuild',
      targets = 'msbuild',
    },
    pattern = {
      [ [[.*\..*proj]] ] = 'msbuild',
    },
  })
vim.lsp.config['msbuild_project_tools_server'] = {
  cmd = {
    'msbuild-ls'
  },
}
vim.treesitter.language.register('xml',
  {
    'msbuild'
  })