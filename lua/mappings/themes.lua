-- lua/mappings/themes.lua
local M = {}

-- Setup function that will be called by your mappings loader
M.setup = function()
  local map = vim.keymap.set
  local keymap_opts = { noremap = true, silent = true }
  local which_key = require("which-key")
  local function get_colorschemes()
    local themes = {}
    for _, theme in pairs(vim.fn.getcompletion("", "color")) do
      table.insert(themes, theme)
    end
    return themes
  end
  local function generate_theme_mappings()
    local themes = get_colorschemes()
    local theme_mappings = {}
    for _, theme in ipairs(themes) do
      theme_mappings[theme] = { "<cmd>colorscheme " .. theme .. "<cr>", theme }
    end
    theme_mappings["n"] = { "<cmd>lua require('telescope.builtin').colorscheme{}<cr>", "Choose Theme" }
    return theme_mappings
  end
  local theme_mappings = generate_theme_mappings()
  local mappings = {
    t = {
      name = "Themes",
    },
  }
  for theme, command in pairs(theme_mappings) do
    mappings.t[theme] = command
  end
  local which_key_opts = {
    prefix = "<leader>",
  }
  which_key.register(mappings, which_key_opts)
end

return M
