return {
	"supermaven-inc/supermaven-nvim",
	lazy = true,
	config = function()
		require("supermaven-nvim").setup({
			-- Optional configuration settings
			-- For example:
			-- keymaps = {
			--   accept_suggestion = "<Tab>",
			--   clear_suggestion = "<C-]>",
			--   accept_word = "<C-j>",
			-- },
			-- ignore_filetypes = { cpp = true },
			-- color = {
			--   suggestion_color = "#ffffff",
			--   cterm = 244,
			-- },
			-- log_level = "info",
			-- disable_inline_completion = false,
			-- disable_keymaps = false,
			-- condition = function()
			--   return false
			-- end,
		})
	end,
}
