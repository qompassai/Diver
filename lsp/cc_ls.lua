-- /qompassai/Diver/lsp/ccls.lua
-- Qompass AI C/C++/ObjC (CC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local function switch_source_header(client, bufnr)
  local method_name = 'textDocument/switchSourceHeader'
  local params = vim.lsp.util.make_text_document_params(bufnr)
  client:request(method_name, params, function(err, result)
    if err then
      error(tostring(err))
    end
    if not result then
      vim.notify('corresponding file cannot be determined')
      return
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'ccls',
  },
  filetypes = { ---@type string[]
    'c',
    'cpp',
    'objc',
    'objcpp',
    'cuda',
  },
  ---@type string[]
  init_options = {
    compilationDatabaseDirectory = 'build',
    index = {
      threads = 0,
    },
    clang = {
      excludeArgs =
      {
        '-frounding-math'
      },
    },
  },
  offset_encoding = 'utf-32',
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspCclsSwitchSourceHeader', function()
      switch_source_header(client, bufnr)
    end, { desc = 'Switch between source/header' })
  end,
  root_markers = {
    'compile_commands.json',
    '.ccls',
    '.git'
  },
  workspace_required = true
}