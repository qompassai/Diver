-- ~/.config/nvim/lua/config/ui/init.lua
----------------------------------------
local M = {}

function M.setup_all(opts)
  local modules = {
    "css",
    "html",
    "icons",
    "line",
    "md",
    "themes",
  }
  for _, module_name in ipairs(modules) do
    local ok, module = pcall(require, "config.ui." .. module_name)
    if ok and type(module.setup) == "function" then
      module.setup(opts)
    end
  end
end

return M
