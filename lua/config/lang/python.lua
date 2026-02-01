-- /qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local group = api.nvim_create_augroup('Python', {
  clear = true,
})
local log = vim.log
local lsp = vim.lsp
local notify = vim.notify
local schedule = vim.schedule
api.nvim_create_autocmd('BufWritePost', {
  group = group,
  pattern = '*.py',
  callback = function(args)
    require('config.core.lint').lint({
      name = 'bandit',
      bufnr = args.buf,
    })
    require('config.core.lint').lint({
      name = 'vulture',
      bufnr = args.buf,
    })
  end,
})
api.nvim_create_autocmd('BufWritePre', {
  group = group,
  pattern = '*.py',
  callback = function(args)
    lsp.buf.format({
      async = false,
      bufnr = args.buf,
      filter = function(client)
        return client.name == 'ruff_ls'
      end,
    })
  end,
})
api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'python',
  callback = function()
    api.nvim_buf_create_user_command(0, 'PythonLint', function()
      lsp.buf.format({
        filter = function(client)
          return client.name == 'ruff_ls' or client.name == 'pyrefly_ls' or client.name == 'ty_ls'
        end,
      })
      cmd.write()
      notify('Python code linted and formatted', log.levels.INFO)
    end, {})

    api.nvim_buf_create_user_command(0, 'PyTestFile', function()
      local file = fn.expand('%:p')
      cmd('split | terminal pytest ' .. file)
    end, {})
    api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
      local file = fn.expand('%:p')
      local pytcmd = 'pytest ' .. file .. '::' .. fn.expand('<cword>') .. ' -v'
      cmd('split | terminal ' .. pytcmd)
    end, {})
  end,
})
api.nvim_create_autocmd('LspAttach', {
  group = group,
  callback = function(args)
    local client = lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end
    if
        client.name == 'basedpyright'
        or client.name == 'pyrefly_ls'
        or client.name == 'ruff_ls'
        or client.name == 'ty_ls'
    then
      vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end
  end,
})
api.nvim_create_user_command('PyHostPing', function()
  local chan = M.start()
  if not chan then
    return
  end
  local ok, res = pcall(vim.rpcrequest, chan, 'nvim_eval', '"pyhost:ok"')
  if ok then
    notify('Python host responded: ' .. tostring(res), log.levels.INFO)
  else
    notify('Python host ping failed: ' .. tostring(res), log.levels.ERROR)
  end
end, {})
function M.start()
  if M.chan and fn.chanclose then
    return M.chan
  end
  local script = fn.stdpath('config') .. '/scripts/host.py'
  if fn.filereadable(script) == 0 then
    notify('Python RPC host script not found: ' .. script, log.levels.ERROR)
    return nil
  end
  local pycmd = {
    'python3',
    script,
  }
  local chan = fn.jobstart(pycmd,
    {
      rpc = true,
      on_exit = function(_, code, _)
        if code ~= 0 then
          schedule(function()
            notify('Python RPC host exited with code ' .. code, log.levels.WARN)
          end)
        end
        M.chan = nil
      end,
    })
  if chan <= 0 then
    notify('Failed to start Python RPC host', log.levels.ERROR)
    return nil
  end
  M.chan = chan
  return chan
end

return M