-- /qompassai/Diver/lua/config/lang/php.lua
-- Qompass AI Diver PHP Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -----------------------------------------
local M = {}
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})
function M.php_autocmds()
  vim.api.nvim_create_user_command("PhpStan", function()
    if vim.fn.executable("phpstan") == 1 then
      vim.cmd("!phpstan analyse")
    else
      vim.notify("phpstan not found in PATH", vim.log.levels.ERROR)
    end
  end, { desc = "Run PHPStan analysis" })
  vim.api.nvim_create_user_command("Pint", function()
    if vim.fn.executable("pint") == 1 then
      vim.cmd("!pint")
    else
      vim.notify("pint not found in PATH", vim.log.levels.ERROR)
    end
  end, { desc = "Run Laravel Pint formatter" })
end

function M.php_dap()
  local dap = require("dap")
  dap.adapters.php = {
    type = "executable",
    command = "node",
    args = {
      os.getenv("HOME") .. "/.local/share/vscode-php-debug/out/phpDebug.js",
    },
  }
  dap.configurations.php = {
    {
      type = "php",
      request = "launch",
      name = "Listen for Xdebug",
      port = 9003,
      pathMappings = { ["/var/www/html"] = "${workspaceFolder}" },
    },
  }
end

function M.nls()
  local null_ls = require("null-ls")
  return {
    null_ls.builtins.formatting.pint.with({ command = "pint" }),
    null_ls.builtins.diagnostics.phpstan.with({
      command = "phpstan",
      extra_args = { "analyse", "--error-format=json" },
    }),
  }
end

return M
