-- /qompassai/Diver/lua/config/lang/go.lua
-- Qompass AI Diver Go Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@meta
---@module 'config.lang.go'

local M = {}

local function go_dap()
  return require('dap')
end

function M.go_dap()
  ---@param cmd string
  ---@return string|nil
  function run_cached_gvm(cmd)
    local handle = io.popen('bash -c \'source ~/.gvm/scripts/gvm && ' .. cmd .. '\'')
    if not handle then
      return nil
    end
    local result = handle:read('*a')
    handle:close()
    return result and vim.trim(result) or nil
  end

  ---Get dlv binary path, falling back to "dlv".
  ---@return string
  local function get_dlv_bin()
    return run_cached_gvm('which dlv') or 'dlv'
  end

  local dap_go_ok, dap_go = pcall(require, 'dap-go')
  if dap_go_ok then
    dap_go.setup({
      delve = {
        path = get_dlv_bin(),
        initialize_timeout_sec = 20,
        port = '${port}',
      },
    })
  end

  local dapui_ok, dapui = pcall(require, 'dapui')
  if dapui_ok then
    dapui.setup()
    local dap = go_dap()
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end
  end
end

---Configure Go language tooling.
---@param opts table|nil
function M.go_cfg(opts)
  opts = opts or {}
end

return M