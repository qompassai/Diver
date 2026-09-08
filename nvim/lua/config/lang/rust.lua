-- /qompassai/Diver/lua/config/lang/rust.lua
-- Qompass AI Diver Rust Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
local M = {}
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local code_action = vim.lsp.buf.code_action
local fn = vim.fn
local get = vim.diagnostic.get
local header = require('utils.docs.docs')
local protocol = vim.lsp.protocol
local group = api.nvim_create_augroup('Rust', {
  clear = true,
})
local usercmd = vim.api.nvim_create_user_command
local WARN = vim.log.levels.WARN
function M.rust_autocmds()
  autocmd('BufNewFile', {
    group = group,
    pattern = { '*.rs' },
    callback = function()
      if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
        return
      end
      local filepath = fn.expand('%:p')
      local hdr = header.make_header(filepath, '//')
      api.nvim_buf_set_lines(0, 0, 0, false, hdr)
      vim.cmd('normal! G')
    end,
  })
  autocmd('BufWritePre', {
    group = group,
    pattern = '*.rs',
    callback = function(args)
      vim.lsp.buf.format({
        bufnr = args.buf,
        async = true,
      })
    end,
  })
  autocmd('BufWritePre', {
    group = group,
    pattern = '*.rs',
    callback = function(args)
      local diagnostics = get(args.buf)
      code_action({
        context = {
          diagnostics = diagnostics,
          only = {
            'source.fixAll',
            'source.organizeImports',
          },
          triggerKind = protocol.CodeActionTriggerKind.Source,
        },
        apply = true,
        filter = function(_, client_id)
          local client = vim.lsp.get_client_by_id(client_id)
          return client ~= nil and client.name == 'rust_analyzer'
        end,
      })
    end,
  })
  usercmd('RustQuickfix', function()
    local diagnostics = get(0)
    code_action({
      context = {
        diagnostics = diagnostics,
        only = {
          'quickfix',
        },
        triggerKind = protocol.CodeActionTriggerKind.Invoked,
      },
      apply = true,
      filter = function(_, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil and client.name == 'rust_analyzer'
      end,
    })
  end, {})
  usercmd('RustCodeAction', function()
    local diagnostics = get(0)
    code_action({
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
  usercmd('RustRangeAction', function()
    local bufnr = 0
    local diagnostics = get(bufnr)
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    code_action({
      context = {
        diagnostics = diagnostics,
        only = {
          'quickfix',
          'refactor.extract',
        },
      },
      range = {
        start = {
          start_pos[1],
          start_pos[2],
        },
        ['end'] = {
          end_pos[1],
          end_pos[2],
        },
      },
      filter = function(_, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        return client ~= nil and client.name == 'rust_analyzer'
      end,
      apply = false,
    })
  end, {
    range = true,
  })
  usercmd('RustCheck', function()
    fn.jobstart({
      'cargo',
      'check',
    }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stderr = function(_, data, _)
        if not data then
          return
        end
        local out = table.concat(data, '')
        if out ~= '' then
          vim.schedule(function()
            vim.notify('cargo check: ' .. out, WARN)
          end)
        end
      end,
    })
  end, {})
  usercmd('RustClippy', function()
    fn.jobstart({
      'cargo',
      'clippy',
    }, {
      stdout_buffered = true,
      stderr_buffered = true,
      on_stderr = function(_, data, _)
        if not data then
          return
        end
        local out = table.concat(data, '')
        if out ~= '' then
          vim.schedule(function()
            vim.notify('cargo clippy: ' .. out, WARN)
          end)
        end
      end,
    })
  end, {})
  autocmd('BufWritePre', {
    group = group,
    pattern = '*.rs',
    callback = function()
      vim.lsp.buf.format({
        async = true,
      })
    end,
  })
  autocmd('FileType', {
    pattern = 'rust',
    callback = function()
      local ok, rustmap = pcall(require, 'mappings.rustmap')
      if ok and rustmap and type(rustmap.setup) == 'function' then
        rustmap.setup()
      end
    end,
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
  api.nvim_create_autocmd('BufRead', {
    group = group,
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
      command = fn.exepath('codelldb') or '/usr/bin/codelldb',
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
        return fn.input('Path to executable: ' .. fn.getcwd() .. '/')
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

function M.rust_cfg(opts)
  opts = opts or {}
  M.rust_autocmds()
  M.rust_dap()
  M.rust_crates()
end

return M