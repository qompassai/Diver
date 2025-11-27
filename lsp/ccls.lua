-- /qompassai/Diver/lsp/ccls.lua
-- Qompass AI C/C++/ObjC (CC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References:  https://github.com/MaskRay/ccls/wiki | https://clang.llvm.org/docs/JSONCompilationDatabase.html | https://cmake.org/cmake/help/latest/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html | https://github.com/rizsotto/Bear | https://github.com/MaskRay/ccls/wiki/Customization#initialization-options
---
---
local function ccls_switch_source_header(client, bufnr)
  local params = vim.lsp.util.make_text_document_params(bufnr)
  client:request('textDocument/switchSourceHeader', params, function(err, result)
    if err then
      vim.notify(tostring(err), vim.log.levels.ERROR)
      return
    end
    if not result then
      vim.notify('corresponding file cannot be determined')
      return
    end
    vim.cmd.edit(vim.uri_to_fname(result))
  end, bufnr)
end
vim.lsp.config('ccls', {
  cmd = { 'ccls' },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  offset_encoding = 'utf-32',
  root_dir = function(fname)
    return vim.fs.dirname(vim.fs.find({ 'compile_commands.json', '.ccls', '.git' }, { upward = true, path = fname })[1])
  end,
  init_options = {
    compilationDatabaseDirectory = 'build',
    index = { threads = 0 },
    clang = { excludeArgs = { '-frounding-math' } },
  },
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, 'LspCclsSwitchSourceHeader', function()
      ccls_switch_source_header(client, bufnr)
    end, { desc = 'Switch between source/header' })
  end,
  workspace_required = true,
})