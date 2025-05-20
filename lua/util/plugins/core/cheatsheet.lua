return {
	"sudormrfbin/cheatsheet.nvim",
	lazy = true,
	keys = {
		{ "<leader>?", "<cmd>Cheatsheet<CR>", desc = "Open Cheatsheet" },
	},
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"nvim-treesitter/nvim-treesitter",
		"jvgrootveld/telescope-zoxide",
		"nvim-lua/plenary.nvim",
		"folke/which-key.nvim",
	},
	config = function()
		require("cheatsheet").setup({
			bundled_cheatsheets = true,
			bundled_plugin_cheatsheets = true,
			include_only_installed_plugins = true,
			telescope_mappings = {
				["<CR>"] = require("cheatsheet.telescope.actions").select_or_fill_commandline,
				["<A-CR>"] = require("cheatsheet.telescope.actions").select_or_execute,
				["<C-Y>"] = require("cheatsheet.telescope.actions").copy_cheat_value,
				["<C-E>"] = require("cheatsheet.telescope.actions").edit_user_cheatsheet,
			},
		})
	end,
}
