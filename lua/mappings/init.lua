-- lua/mappings/init.lua
local M = {}

M.setup = function()
  local mapping_files = {
    "aimap",
    "cicdmap",
    "datamap",
    "diagmap",
    "disable",
    "genmap",
    "langmap",
    "navmap",
    "pymap",
    "rustmap",
    "source",
    "settings",
    "themes",
  }

  for _, name in ipairs(mapping_files) do
    local ok, mod = pcall(require, "mappings." .. name)
    if ok then
      if type(mod) == "table" and type(mod.setup) == "function" then
        mod.setup()
      else
        vim.notify("Module '" .. name .. "' does not have a setup function", vim.log.levels.WARN)
      end
    else
      vim.notify("Failed to load mappings: " .. name, vim.log.levels.WARN)
    end
  end
end

return M
