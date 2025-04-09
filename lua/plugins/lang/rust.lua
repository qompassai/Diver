return {
	{
		"mrcjkb/rustaceanvim",
		version = "^5",
		ft = { "rust" },
		lazy = true,
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
			{
				"rust-lang/rust.vim",
				ft = "rust",
				init = function()
					vim.g.rustfmt_autosave = 1
				end,
				lazy = false,
			},
			"mfussenegger/nvim-dap",
			"rcarriga/nvim-dap-ui",
		},
		config = function()
			require("config.rust").setup()
		end,
	},

	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "toml",
				callback = function(opts)
					local buffer = opts.buf
					local map = function(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = buffer, desc = desc })
					end
					map("<leader>cu", function() require("crates").upgrade_crate() end,
						"Upgrade crate")
					map("<leader>cU", function() require("crates").upgrade_all_crates() end,
						"Upgrade all crates")
					map("<leader>cv", function() require("crates").show_versions_popup() end,
						"Show crate versions")
				end,
			})
		end,
	},
}
