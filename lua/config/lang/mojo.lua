-- /qompassai/Diver/lua/config/lang/mojo.lua
-- Qompass AI Diver Mojo Lang Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version 5.1, JIT
local api = vim.api
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local client_by_id = vim.lsp.get_client_by_id
local code_action = vim.lsp.buf.code_action
local ERROR = vim.log.levels.ERROR
local expand = vim.fn.expand --[[@as fun(path: string): string]]
local filereadable = vim.fn.filereadable
local get = vim.diagnostic.get
local INFO = vim.log.levels.INFO
local jobstart = vim.fn.jobstart
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
local header = require('utils.docs.docs')
local group = augroup('Mojo', {
  clear = true,
})
local usercmd = vim.api.nvim_create_user_command
---@return string?
local function safe_expand(path) ---@param path string
  local result = expand(path)
  local expanded = type(result) == 'string' and result or nil ---@type string?
  if not expanded or expanded == '' then
    return nil
  end
  return expanded
end
local MOJO_BIN = safe_expand('~/.local/share/mojo/.pixi/envs/default/bin/mojo')
local MOJO_LLDB_DAP = safe_expand('~/.local/share/mojo/.pixi/envs/default/bin/mojo-lldb-dap')
local CONDA_PREFIX = safe_expand('~/.local/share/mojo/.pixi/envs/default')
---@return boolean
local function check_mojo_installed()
  if not MOJO_BIN or filereadable(MOJO_BIN) == 0 then
    notify('Mojo binary not found. Install from https://docs.modular.com/mojo/', ERROR)
    return false
  end
  return true
end

---@return boolean
local function is_command_available(cmd) ---@param cmd string?
  if not cmd then
    return false
  end
  return filereadable(cmd) == 1
end
autocmd('BufNewFile', {
  group = group,
  pattern = {
    '*.mojo',
    '*.🔥',
  },
  callback = function()
    local lines = api.nvim_buf_get_lines(0, 0, 1, false) ---@type string[]
    if lines[1] ~= '' then
      return
    end
    local filepath = expand('%:p') ---@type string
    local hdr = header.make_header(filepath, '#')
    api.nvim_buf_set_lines(0, 0, 0, false, hdr)
    vim.cmd('normal! G')
  end,
})
autocmd('FileType', {
  group = group,
  pattern = 'mojo',
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].tabstop = 4
    vim.bo[bufnr].shiftwidth = 4
    vim.bo[bufnr].expandtab = true
    vim.bo[bufnr].commentstring = '# %s'
    vim.opt_local.formatoptions:append('jcroql')
  end,
})
autocmd('BufWritePre', {
  group = group,
  pattern = {
    '*.mojo',
    '*.🔥',
  },
  callback = function(args) ---@param args {buf: integer, file: string, match: string}
    lsp.buf.format({
      bufnr = args.buf,
      async = false,
    })
  end,
})
autocmd('BufWritePre', {
  group = group,
  pattern = {
    '*.mojo',
    '*.🔥',
  },
  callback = function()
    code_action({
      context = {
        diagnostics = {},
        only = {
          'source.fixAll',
        },
      },
      apply = true,
    })
  end,
})
usercmd('MojoCompile', function()
  if not check_mojo_installed() then
    return
  end
  local current_file = expand('%:p')
  jobstart({
    MOJO_BIN,
    'build',
    current_file,
    '-o',
    expand('%:p:r'),
  }, {
    on_exit = function(_, code, _)
      schedule(function()
        if code == 0 then
          notify('Compilation successful', INFO)
        else
          notify('Compilation failed', ERROR)
        end
      end)
    end,
  })
end, {})
usercmd('MojoRun', function()
  if not check_mojo_installed() then
    return
  end
  local current_file = expand('%:p')
  jobstart({
    MOJO_BIN,
    'run',
    current_file,
  }, { detach = true })
end, {})
usercmd('MojoTest', function()
  local current_file = expand('%:p')
  jobstart({
    MOJO_BIN,
    'test',
    current_file,
  }, {
    detach = false,
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        schedule(function()
          vim.notify(table.concat(data, '\n'), INFO)
        end)
      end
    end,
  })
end, {})
usercmd('MojoFormat', function()
  local current_file = expand('%:p')
  jobstart({
    MOJO_BIN,
    'format',
    current_file,
  }, {
    on_exit = function(_, code, _)
      schedule(function()
        if code == 0 then
          notify('Formatted successfully', INFO)
          vim.cmd('e!')
        else
          notify('Format failed', ERROR)
        end
      end)
    end,
  })
end, {})
usercmd('MojoRepl', function()
  vim.cmd('terminal ' .. MOJO_BIN .. ' repl')
end, {})
usercmd('MojoQuickfix', function()
  local diagnostics = get(0)
  code_action({
    context = {
      diagnostics = diagnostics,
      only = {
        'quickfix',
      },
      triggerKind = lsp.protocol.CodeActionTriggerKind.Invoked,
    },
    apply = true,
  })
end, {})

autocmd('BufWritePre', {
  group = group,
  pattern = { '*.mojo', '*.🔥' },
  callback = function(args)
    local diagnostics = get(args.buf)
    code_action({
      context = {
        diagnostics = diagnostics,
        only = {
          'source.organizeImports',
          'source.fixAll',
        },
        triggerKind = lsp.protocol.CodeActionTriggerKind.Source,
      },
      apply = true,
      filter = function(_, client_id)
        local client = client_by_id(client_id)
        return client ~= nil and (client.name == 'mojo' or client.name == 'mojo_ls')
      end,
    })
  end,
})
autocmd('BufWritePost', {
  group = group,
  pattern = {
    '*.mojo',
    '*.🔥',
  },
  callback = function(args)
    jobstart({
      MOJO_BIN,
      'check',
      api.nvim_buf_get_name(args.buf),
    }, {
      stdout_buffered = true,
      on_stdout = function(_, data, _)
        if not data then
          return
        end
        local out = table.concat(data, '')
        if out ~= '' and not out:match('^%s*$') then
          schedule(function()
            notify('mojo check: ' .. out, INFO)
          end)
        end
      end,
    })
  end,
})
usercmd('MojoCodeAction', function()
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
      local client = client_by_id(client_id)
      return client ~= nil and (client.name == 'mojo' or client.name == 'mojo_ls')
    end,
    apply = true,
  })
end, {})
usercmd('MojoRangeAction', function()
  local bufnr = 0
  local diagnostics = get(bufnr)
  local start_pos = api.nvim_buf_get_mark(bufnr, '<')
  local end_pos = api.nvim_buf_get_mark(bufnr, '>')
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
      local client = client_by_id(client_id)
      return client ~= nil and (client.name == 'mojo' or client.name == 'mojo_ls')
    end,
    apply = false,
  })
end, {
  range = true,
})
autocmd('LspAttach', {
  group = group,
  callback = function(args)
    local client = client_by_id(args.data.client_id)
    if client and (client.name == 'mojo' or client.name == 'mojo_ls') then
      vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end
  end,
})
usercmd('MojoDebug', function()
  if not check_mojo_installed() then
    return
  end
  if not is_command_available(MOJO_LLDB_DAP) then
    notify('Mojo LLDB DAP not found at: ' .. MOJO_LLDB_DAP, ERROR)
    return
  end
  local dap_ok, dap = pcall(require, 'dap')
  if not dap_ok then
    notify('nvim-dap not available', ERROR)
    return
  end
  if not dap.adapters.mojo_lldb then
    dap.adapters.mojo_lldb = {
      type = 'executable',
      command = MOJO_LLDB_DAP,
      env = { CONDA_PREFIX = CONDA_PREFIX },
      name = 'mojo_lldb',
    }
  end
  if not dap.configurations.mojo then
    dap.configurations.mojo = {
      {
        name = 'Mojo: Launch file',
        type = 'mojo_lldb',
        request = 'launch',
        program = function()
          return api.nvim_buf_get_name(0)
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
      },
    }
  end
  dap.continue()
end, {})
return M