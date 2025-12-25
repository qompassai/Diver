-- qompassai/Diver/lua/config/lang/ts.lua
-- Qompass AI Diver Typescript Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@meta
---@module 'config.lang.ts'
local M = {}
function M.ts_autocmds()
  local function execute_command(command, arguments)
    if vim.lsp.commands and vim.lsp.commands.execute then
      vim.lsp.commands.execute({ command = command, arguments = arguments })
    else
      client:exec_cmd({
        command = command,
        arguments = arguments,
      })
    end
  end
  vim.api.nvim_create_user_command('TypescriptOrganizeImports', function()
    execute_command('_typescript.organizeImports',
      { vim.api.nvim_buf_get_name(0) })
  end, { desc = 'Organize Imports' })
  vim.api.nvim_create_user_command('TypescriptAddMissingImports', function()
    execute_command('_typescript.addMissingImports', { vim.api.nvim_buf_get_name(0) })
  end, { desc = 'Add Missing Imports' })
  vim.api.nvim_create_user_command('TypescriptFixAll', function()
    execute_command('_typescript.fixAll', { vim.api.nvim_buf_get_name(0) })
  end, { desc = 'Fix All Fixable Issues' })
  vim.api.nvim_create_user_command('TypescriptGoToSourceDefinition', function()
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local col = vim.api.nvim_win_get_cursor(0)[2]
    execute_command('_typescript.goToSourceDefinition', { vim.api.nvim_buf_get_name(0), row, col })
  end, { desc = 'Go To Source Definition' })
end

function M.ts_lsp(opts)
  opts = opts or {}
  local on_attach = opts.on_attach
      or function(client, bufnr)
        if M.lsp_on_attach then
          M.lsp_on_attach(client, bufnr)
        end
      end
  local config = vim.tbl_deep_extend('force', {
    on_attach = on_attach,
    handlers = opts.handlers or {},
    settings = {
      separate_diagnostic_server = true,
      publish_diagnostic_on = 'insert_leave',
      expose_as_code_action = {},
      tsserver_path = nil,
      tsserver_plugins = {},
      tsserver_max_memory = 'auto',
      tsserver_format_options = {},
      tsserver_file_preferences = {},
      tsserver_locale = 'en',
      complete_function_calls = true,
      include_completions_with_insert_text = true,
      code_lens = 'off',
      disable_member_code_lens = true,
      jsx_close_tag = {
        enable = true,
        filetypes = {
          'javascriptreact',
          'typescriptreact'
        },
      },
    },
  }, opts)
  require('typescript-tools').setup(config)
end

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
      ['tsconfig.*%.json'] = 'jsonc'
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
  opts.defaults = vim.tbl_deep_extend('force', opts.defaults or {}, {
    ['<leader>ct'] = { name = '+typescript' },
    ['<leader>ctf'] = {
    },
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

function M.ts_treesitter(opts)
  opts = opts or {}
  return {
    ensure_installed = {},
    highlight = {
      enable = true,
      disable = {},
    },
    indent = {
      enable = true,
    },
  }
end

function M.ts_cfg(opts)
  opts = opts or {}
  return {
    linter = M.ts_linter(opts),
    keymaps = M.ts_keymaps(opts),
    filetypes = M.ts_filetype_detection,
    commands = M.ts_project_commands,
    root_dir = M.ts_root_dir,
  }
end

return M