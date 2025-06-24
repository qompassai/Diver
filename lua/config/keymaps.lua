-- ~/.config/nvim/lua/config/keymaps.lua
local M = {}
local safe_require = _G.safe_require
M.setup = function()
  local mappings = safe_require("mappings")
  if mappings then
    mappings.setup()
  end
end
return M
