-- /qompassai/Diver/lsp/stylua_ls.lua
-- Qompass AI Diver Stylua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'stylua',
    '--lsp',
    '--search-parent-directories',
    '--sort-requires',
    '--respect-ignores',
    '--syntax=LuaJIT',
  },
  filetypes = {
    'lua',
    'luau',
  },
  on_attach = function(client)
    client.server_capabilities.documentFormattingProvider = true
    client.server_capabilities.documentRangeFormattingProvider = true
    client.server_capabilities.completionProvider = nil
    client.server_capabilities.hoverProvider = false
    client.server_capabilities.definitionProvider = false
    client.server_capabilities.referencesProvider = false
    client.server_capabilities.renameProvider = false
    client.server_capabilities.codeActionProvider = false
  end,
  root_markers = {
    '.editorconfig',
    '.stylua.toml',
    'stylua.toml',
  },
  settings = {
    stylua = {
      block_newline_gaps = 'Never',
      call_parentheses = 'Always',
      collapse_simple_statement = 'Always',
      column_width = 120,
      indent_type = 'Spaces',
      indent_width = 2,
      line_endings = 'Unix',
      quote_style = 'ForceSingle',
      space_after_function_names = 'Never',
      sort_requires = {
        enabled = true,
      },
      syntax = 'LuaJIT',
    },
  },
}