-- /qompassai/Diver/lua/config/lang/php.lua
-- Qompass AI Diver PHP Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
---@meta
---@module 'config.lang.php'
local M = {}
vim.api.nvim_create_user_command('PhpStan', function()
  if vim.fn.executable('phpstan') == 1 then
    vim.cmd('!phpstan analyse')
  else
    vim.echo('phpstan not found in PATH', vim.log.levels.ERROR)
  end
end, {
  desc = 'Run PHPStan analysis',
})
vim.api.nvim_create_user_command('Pint', function()
  if vim.fn.executable('pint') == 1 then
    vim.cmd('!pint')
  else
    vim.echo('pint not found in PATH', vim.log.levels.ERROR)
  end
end, {
  desc = 'Run Laravel Pint formatter',
})
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client_id = args.data and args.data.client_id
    if not client_id then
      return
    end
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
      return
    end
    if client:supports_method('textDocument/foldingRange') then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldexpr = 'v:lua.vim.lsp.foldexpr()'
    end
  end,
})

function M.php_dap()
  local dap = require('dap')
  dap.adapters.php = {
    type = 'executable',
    command = 'node',
    args = {
      os.getenv('HOME') .. '/.local/share/vscode-php-debug/out/phpDebug.js',
    },
  }
  dap.configurations.php = {
    {
      type = 'php',
      request = 'launch',
      name = 'Listen for Xdebug',
      port = 9003,
      pathMappings = {
        ['/var/www/html'] = '${workspaceFolder}'
      },
    },
  }
end

return M