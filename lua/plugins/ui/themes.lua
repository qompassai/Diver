-- ~/.config/nvim/lua/plugins/ui/themes.lua
return {
  {
		"tribela/transparent.nvim",
		lazy = false,
		enable = true,
		event = "VimEnter",
		config = true,
	},
  {
  	"norcalli/nvim-colorizer.lua",
	lazy = true,
	event = "BufReadPre",
	config = function()
		require("colorizer").setup({
			filetypes = {
				"*",
				css = { css = true },
			},
			user_default_options = {
				names = true,
			},
		})
	end,
},
  {
  "vyfor/cord.nvim",
  priority = 1000,
  lazy = false,
  dependencies = {
    "catppuccin/nvim",
    "folke/tokyonight.nvim",
    "navarasu/onedark.nvim",
    "sainnhe/gruvbox-material",
    "EdenEast/nightfox.nvim",
    "shaunsingh/nord.nvim",
    "marko-cerovac/material.nvim",
    "Mofiqul/dracula.nvim",
    "projekt0n/github-nvim-theme",
    "olimorris/onedarkpro.nvim",
  },
config = function()
  local ok, themes = pcall(require, "config.ui.themes")
  if not ok then
    vim.notify("Failed to load theme config: " .. tostring(themes), vim.log.levels.ERROR)
    return
  end
  if not themes.apply_current_theme() then return end
  local setup_ok, cord = pcall(themes.setup_cord)
  if not setup_ok then
    vim.notify("Cord setup failed: " .. tostring(cord), vim.log.levels.ERROR)
    return
  end
  themes.cord = cord
  themes.cord_initialized = true
  themes.update_cord_theme()
end,
}
}
