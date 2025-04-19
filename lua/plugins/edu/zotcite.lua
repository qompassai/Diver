return {
	"jalvesaq/zotcite",
  ft = { "markdown", "text", "latex", "tex" },
	lazy = true,
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-telescope/telescope.nvim",
	},
	config = function()
		require("zotcite").setup({
			python_path = "/usr/bin/python3",
		})
	end,
}
