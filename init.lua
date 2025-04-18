-- init.lua
pcall(vim.loader.enable)
vim.g.mapleader = " "
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
--vim.api.nvim_create_autocmd("VimEnter", {
--  callback = function()
--    local handle = io.popen("find . -name '*.lua' -exec file {} \\; | grep -v 'UTF-8'")
--    local output = handle and handle:read("*a") or ""
--    if output ~= "" then
--      vim.schedule(function()
--        vim.notify("⚠️ Non-UTF-8 Lua files detected:\n" .. output, vim.log.levels.ERROR)
--      end)
--    end
--require- end,
--})
--vim.api.nvim_create_user_command("FixAsciiEncoding", function()
--  vim.fn.system([[
--    find . -name '*.lua' -exec bash -c 'iconv -f ascii -t utf-8 "{}" -o "{}.utf8" && mv "{}.utf8" "{}"' \;
--  ]])
--  vim.notify("Converted ASCII files to UTF-8", vim.log.levels.INFO)
--end, {})
vim.opt.wildignore:append({
  "*/.cache/paru/clone/*",
  "*/.cache/yay/*",
  "**/pkg/*",
  "**/.config/*",
})
--vim.lsp.set_log_level("debug")
vim.opt.termguicolors = true
vim.g.which_key_disable_health_check = 1
require("config.autocmds")
require("config.options")
require("config.lazy")
require("config.keymaps").setup()
