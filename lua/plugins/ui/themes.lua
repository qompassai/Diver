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
    lazy = false,
    dependencies = {
      { "catppuccin/nvim", name = "catppuccin" },
      { "folke/tokyonight.nvim", name = "tokyonight" },
      { "navarasu/onedark.nvim", name = "onedark" },
      { "sainnhe/gruvbox-material", name = "gruvbox-material" },
      { "EdenEast/nightfox.nvim", name = "nightfox" },
      { "shaunsingh/nord.nvim", name = "nord" },
      { "marko-cerovac/material.nvim", name = "material" },
      { "Mofiqul/dracula.nvim", name = "dracula" },
      { "projekt0n/github-nvim-theme", name = "github-nvim-theme" },
      { "olimorris/onedarkpro.nvim", name = "onedarkpro" },
      { "navarasu/onedark.nvim", name = "onedark" },
    },
    config = function()
      require("config.ui.themes").setup_all()
    end,
  }
}
