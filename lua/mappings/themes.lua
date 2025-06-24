-- lua/mappings/themes.lua
local M = {}
M.setup = function()
  local which_key = require("which-key")
  local theme_mappings = setmetatable({}, {
    __index = function(t)
      rawset(t, "c", {
        name = "Themes",
        n = {
          cmd = "<cmd>lua require('fzf-lua').colorscheme({ previewer = true })<cr>",
          desc = "Choose Theme",
        },
      })
      local themes = vim.fn.getcompletion("", "color")
      for _, theme in ipairs(themes) do
        t.c[theme] = {
          cmd = ("<cmd>lua vim.cmd('colorscheme %s')<cr>"):format(theme),
          desc = theme:gsub("^%l", string.upper),
        }
      end
      return t.c
    end,
  })
  which_key.register(theme_mappings, {
    mode = "n",
    buffer = nil,
    silent = true,
    noremap = true,
  })
end
if pcall(require, "which-key") then
  M.setup()
else
  vim.api.nvim_create_autocmd("User", {
    pattern = "WhichKeySetupPost",
    callback = M.setup,
  })
end
return M
