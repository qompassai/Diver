-- lua/mappings/themes.lua
local M = {}

M.setup = function()
  local which_key = require("which-key")

  local theme_mappings = setmetatable({}, {
    __index = function(t)
      rawset(t, "T", {
        name = "Themes",
        n = { "<cmd>lua require('fzf-lua').colorscheme({ previewer = true })<cr>", "Choose Theme" },
      })

      local themes = vim.fn.getcompletion("", "color")
      for _, theme in ipairs(themes) do
        t.T[theme] = {
          ("<cmd>lua vim.cmd('colorscheme %s')<cr>"):format(theme),
          theme:gsub("^%l", string.upper),
        }
      end
      return t.T
    end,
  })
  which_key.register(theme_mappings, {
    mode = "n",
    prefix = "<leader>",
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
