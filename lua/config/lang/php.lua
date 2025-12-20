-- /qompassai/Diver/lua/config/lang/php.lua
-- Qompass AI Diver PHP Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
---@meta
---@module 'config.lang.php'
local M = {}

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
      pathMappings = { ['/var/www/html'] = '${workspaceFolder}' },
    },
  }
end

return M