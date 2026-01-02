-- qompassai/Diver/lua/config/lang/ts.lua
-- Qompass AI Diver Typescript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta
---@module 'config.lang.ts'
local M = {}
function M.ts_root_dir(fname)
  util = util
  local root = util.root_pattern(
    'tsconfig.json',
    'jsconfig.json',
    'package.json',
    '.eslintrc.js',
    '.eslintrc.json',
    '.eslintrc.cjs'
  )(fname) or util.root_pattern('.git')(fname)
  return root or vim.fn.getcwd()
end

---@return boolean
function M.ts_filetype_detection()
  vim.filetype.add({
    extension = {
      ts = 'typescript',
      tsx = 'typescriptreact',
      js = 'javascript',
      jsx = 'javascriptreact',
      mjs = 'javascript',
      cjs = 'javascript',
    },
    pattern = {
      ['.*%.d.ts'] = 'typescript',
      ['tsconfig.*%.json'] = 'jsonc',
    },
    filename = {
      ['tsconfig.json'] = 'jsonc',
      ['.eslintrc.js'] = 'javascript',
      ['.eslintrc.cjs'] = 'javascript',
    },
  })
  return true
end

function M.ts_keymaps(opts)
  opts = opts or {}
  opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {},
    {
      ['<leader>ct'] = {
        name = '+typescript'
      },
      ['<leader>ctf'] = {},
      ['<leader>cta'] = {
        '<cmd>lua vim.lsp.buf.code_action()<cr>',
        'Code Actions',
      },
      ['<leader>ctr'] = { '<cmd>lua vim.lsp.buf.rename()<cr>', 'Rename Symbol' },
      ['<leader>cti'] = {
        '<cmd>TypescriptOrganizeImports<cr>',
        'Organize Imports',
      },
      ['<leader>ctd'] = {
        '<cmd>TypescriptGoToSourceDefinition<cr>',
        'Go To Definition',
      },
      ['<leader>ctt'] = {
        '<cmd>TypescriptAddMissingImports<cr>',
        'Add Missing Imports',
      },
      ['<leader>cts'] = {
        '<cmd>lua require(\'telescope.builtin\').lsp_document_symbols()<cr>',
        'Document Symbols',
      },
    })
  return opts
end

function M.ts_cfg(opts)
  opts = opts or {}
  return {
    keymaps = M.ts_keymaps(opts),
    filetypes = M.ts_filetype_detection,
    root_dir = M.ts_root_dir,
  }
end

return M