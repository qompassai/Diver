-- ~/.config/nvim/lua/utils/safe_require.lua
-- -----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
local M = {} ---@return nil|string
function M.safe_require(module_name)
  if package.loaded[module_name] then return package.loaded[module_name] end
  local ok, result = pcall(require, module_name)
  if not ok then
    vim.echo('Error loading ' .. module_name .. ': ' .. result,
      vim.log.levels.ERROR)
    return nil
  end
  package.loaded[module_name] = result
  return result
end

return M