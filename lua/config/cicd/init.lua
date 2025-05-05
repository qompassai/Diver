-- ~/.config/nvim/lua/config/cicd/init.lua
local M = {}

function M.setup_all(opts)
  local modules = {
    "ansible",
    "build",
    "json",
  }
  for _, module_name in ipairs(modules) do
    local ok, module = pcall(require, "config.cicd." .. module_name)
    if ok and type(module.setup) == "function" then
      module.setup(opts)
    end
  end
end

return M
