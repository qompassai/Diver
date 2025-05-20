return {
	"echasnovski/mini.ai",
	enabled = "false",
	version = "*", -- Use the latest stable version
	event = "VeryLazy", -- Load the plugin when needed
	opts = {
		n_lines = 500, -- Number of lines within which textobject is searched
		custom_textobjects = {
			-- Add any custom textobjects here
		},
		search_method = "cover_or_next",
	},
	config = function(_, opts)
		require("mini.ai").setup(opts)
	end,
}
