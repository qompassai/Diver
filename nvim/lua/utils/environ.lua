-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Environment Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

local M = {}

---@param name string
---@return string
function M.getenv(name)
  local envvar = os.getenv(name)
  if envvar == nil then
    vim.notify(name .. " environment variable is not set", vim.log.levels.WARN)
    return ""
  end
  return envvar
end

return M
