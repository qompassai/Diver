-- /qompassai/Diver/lua/config/lang/rust.lua
-- Qompass AI Diver Rust Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
local U = require('utils.lang.rust')
vim.api.nvim_create_autocmd('BufWritePre',
  {
    pattern = {
      '*.rs'
    },
    callback = function(args)
      vim.lsp.buf.format({
        bufnr = args.buf,
        async = true
      })
    end,
  })
vim.api.nvim_create_autocmd('BufWritePre',
  {
    pattern = {
      '*.rs'
    },
    callback = function(args)
      local diagnostics = vim.diagnostic.get(args.buf)
      vim.lsp.buf.code_action({
        context = {
          diagnostics = diagnostics,
          only = {
            'source.fixAll',
            'source.organizeImports',
          },
          triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Source,
        },
        apply = true,
        filter = function(_, client_id)
          local client = vim.lsp.get_client_by_id(client_id)
          return client ~= nil and client.name == 'rust_analyzer'
        end,
      })
    end,
  })
vim.api.nvim_create_user_command('RustQuickfix', function()
  local diagnostics = vim.diagnostic.get(0)
  vim.lsp.buf.code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix'
      },
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    },
    apply = true,
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.name == 'rust_analyzer'
    end,
  })
end, {})
vim.api.nvim_create_user_command('RustCodeAction', function()
  local diagnostics = vim.diagnostic.get(0)
  vim.lsp.buf.code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor',
        'source.organizeImports',
        'source.fixAll',
      },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.name == 'rust_analyzer'
    end,
    apply = true,
  })
end, {})
vim.api.nvim_create_user_command('RustRangeAction', function()
  local bufnr = 0
  local diagnostics = vim.diagnostic.get(bufnr)
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
  vim.lsp.buf.code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
        'refactor.extract'
      },
    },
    range = {
      start = { start_pos[1], start_pos[2] },
      ['end'] = { end_pos[1], end_pos[2] },
    },
    filter = function(_, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      return client ~= nil and client.name == 'rust_analyzer'
    end,
    apply = false,
  })
end, { range = true })
vim.api.nvim_create_user_command('RustCheck', function()
    vim.fn.jobstart({ 'cargo', 'check' },
      {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stderr = function(_, data, _)
          if not data then
            return
          end
          local out = table.concat(data, '')
          if out ~= '' then
            vim.schedule(function()
              vim.notify('cargo check: ' .. out, vim.log.levels.WARN)
            end)
          end
        end,
      })
  end,
  {})
vim.api.nvim_create_user_command('RustClippy', function()
  vim.fn.jobstart({
      'cargo',
      'clippy'
    },
    {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stderr = function(_, data, _)
        if not data then
          return
        end
        local out = table.concat(data, '')
        if out ~= '' then
          vim.schedule(function()
            vim.notify('cargo clippy: ' .. out, vim.log.levels.WARN)
          end)
        end
      end,
    })
end, {})

U.rust_env()
local M = {}
function M.rust_autocmds()
  vim.api.nvim_create_autocmd('BufWritePre',
    {
      pattern = '*.rs',
      callback = function()
        vim.lsp.buf.format({
          async = true,
        })
      end,
    })
  vim.api.nvim_create_autocmd('FileType',
    {
      pattern = 'rust',
      callback = function()
        local ok, rustmap = pcall(require, 'mappings.rustmap')
        if ok and rustmap and type(rustmap.setup) == 'function' then
          rustmap.setup()
        end
      end,
    })
end

function M.rust_cfg(opts)
  opts = opts or {}
  U.rust_auto_toolchain()
  M.rust_dap()
  M.rust_crates()
  vim.api.nvim_create_user_command('RustEdition', function(o)
    U.rust_edition(o.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(U.rust_editions)
    end,
  })
  vim.api.nvim_create_user_command('RustToolchain', function(o)
    U.rust_set_toolchain(o.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(U.rust_toolchains)
    end,
  })
  vim.keymap.set('n', '<leader>re', function()
    vim.ui.select(vim.tbl_keys(U.rust_editions), {
      prompt = 'Select Rust edition',
    }, U.rust_edition)
  end, {
    desc = 'Rust: select edition',
  })
  vim.keymap.set('n', '<leader>rt', function()
    vim.ui.select(vim.tbl_keys(U.rust_toolchains), {
      prompt = 'Select Rust toolchain',
    }, U.rust_set_toolchain)
  end, {
    desc = 'Rust: select toolchain',
  })
end

function M.rust_crates()
  local crates = require('crates')
  crates.setup({
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    smart_insert = true,
    insert_closing_quote = true,
    loading_indicator = true,
    date_format = '%Y-%m-%d',
    thousands_separator = '.',
    notification_title = 'crates.nvim',
    popup = {
      autofocus = false,
      hide_on_select = false,
      border = 'none',
      show_version_date = true,
    },
    lsp = {
      enabled = true,
      name = 'crates.nvim',
      actions = true,
      completion = true,
    },
  })
  vim.api.nvim_create_autocmd('BufRead',
    {
      pattern = 'Cargo.toml',
      callback = function()
        vim.defer_fn(crates.show, 300)
      end,
    })
end

function M.rust_dap()
  local dap = require('dap')
  local dapui = require('dapui')
  dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
      command = vim.fn.exepath('codelldb') or '/usr/bin/codelldb',
      args = {
        '--port',
        '${port}',
      },
    },
  }
  dap.configurations.rust = {
    {
      name = 'Launch',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return vim.fn.input('Path to executable: ' .. vim.fn.getcwd() .. '/')
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
      args = {},
    },
  }
  dap.listeners.after.event_exited.dapui_config = function()
    dapui.close()
  end
end

function M.rust_rustacean(capabilities)
  return {
    tools = {
      float_win_config = {
        border = 'rounded',
      },
    },
    server = U.rust_lsp(M.rust_on_attach, capabilities or U.rust_cmp()),
  }
end

return M