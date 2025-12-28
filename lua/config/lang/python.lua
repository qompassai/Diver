-- /qompassai/Diver/lua/config/lang/python.lua
-- Qompass AI Diver Python Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd('BufWritePost',
  {
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
vim.api.nvim_create_autocmd('FileType',
  {
    pattern = 'python',
    callback = function()
      vim.opt_local.autoindent = true
      vim.opt_local.smartindent = true
      vim.api.nvim_buf_create_user_command(0, 'PythonLint', function()
        vim.lsp.buf.format()
        vim.cmd.write()
        vim.notify('Python code linted and formatted', vim.log.levels.INFO)
      end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFile', function()
        local file = vim.fn.expand('%:p')
        vim.cmd('split | terminal pytest ' .. file)
      end, {})
      vim.api.nvim_buf_create_user_command(0, 'PyTestFunc', function()
        local file = vim.fn.expand('%:p')
        local cmd = 'pytest ' .. file .. '::' .. vim.fn.expand('<cword>') .. ' -v'
        vim.cmd('split | terminal ' .. cmd)
      end, {})
    end,
  })
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.py',
  callback = function(args)
    vim.lsp.buf.format({
      async = false,
      bufnr = args.buf,
      filter = function(client)
        return client.name == 'pyrefly_ls'
            or client.name == 'ruff_ls'
            or client.name == 'ty_ls'
      end,
    })
  end,
})
local blackd = {
  job = nil,
  count = 0,
}
local function start_blackd()
  if blackd.job then
    return
  end
  blackd.job = vim.system({
    'blackd',
    '--bind-host',
    '127.0.0.1',
    '--bind-port',
    '45484',
  }, {
    text = true,
  }, function(res)
    blackd.job = nil
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify('blackd exited with code ' .. res.code, vim.log.levels.WARN)
      end)
    end
  end)
end
local function stop_blackd()
  if not blackd.job then
    return
  end
  blackd.job:kill('term')
  blackd.job = nil
end
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(args)
    blackd.count = blackd.count + 1
    if blackd.count == 1 then
      start_blackd()
    end
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = args.buf,
      once = true,
      callback = function()
        blackd.count = blackd.count - 1
        if blackd.count <= 0 then
          blackd.count = 0
          stop_blackd()
        end
      end,
    })
  end,
})
vim.api.nvim_create_user_command('PyLintAll', function()
  local file = vim.fn.expand('%:p')
  local cmds = {
    { 'ruff',    'check', file },
    { 'bandit',  '-q',    file },
    { 'vulture', file },
    { 'pyrefly', file },
  }
  for _, cmd in ipairs(cmds) do
    if vim.fn.executable(cmd[1]) == 1 then
      vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data, _)
          if not data then
            return
          end
          local out = table.concat(data, '')
          if out ~= '' then
            vim.schedule(function()
              vim.notify(table.concat(cmd, ' ') .. ': ' .. out, vim.log.levels.INFO)
            end)
          end
        end,
      })
    end
  end
end, {})
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.py',
  callback = function(args)
    if vim.fn.executable('blackd-client') == 0 then
      return
    end
    vim.fn.jobstart({ 'blackd-client', vim.api.nvim_buf_get_name(args.buf) }, {
      stdout_buffered = true,
      stderr_buffered = true,
    })
  end,
})
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and (client.name == 'pyrefly_ls'
          or client.name == 'ruff_ls'
          or client.name == 'ty_ls') then
      vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
    end
  end,
})