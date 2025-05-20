return {
	"jamessan/vim-gnupg",
	event = "BufReadPre",
	config = function()
		vim.g.GPGPreferSymmetric = 1
		vim.api.nvim_create_autocmd("User", {
			pattern = "GnuPG",
			callback = function()
				vim.opt_local.textwidth = 72
			end,
		})
	end,
	lazy = true,
}
