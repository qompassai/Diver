--| ~/.config/nvim/init.lua
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/.luarocks/share/lua/5.1/?.lua;" .. home .. "/.luarocks/share/lua/5.1/?/init.lua"
package.cpath = package.cpath .. ";" .. home .. "/.luarocks/lib/lua/5.1/?.so"


_G.safe_require = function(module)
  if package.loaded[module] then
    return package.loaded[module]
  end
  local success, result = pcall(require, module)
  if not success then
    local err_msg = type(result) == "string" and result or vim.inspect(result)
    vim.notify("Error loading " .. module .. ": " .. err_msg, vim.log.levels.ERROR)
    return nil
  end
  package.loaded[module] = result
  return result
end
vim.opt.wildignore:append({
  "*/.cache/paru/clone/*",
  "*/.cache/yay/*",
  "**/pkg/*",
  "**/.config/*",
})
require("config.lazy")
--vim.lsp.set_log_level("debug")
--vim.g.which_key_disable_health_check = 1
require("config.autocmds")
require("config.options")
require("config.keymaps").setup()
require("config.types")
