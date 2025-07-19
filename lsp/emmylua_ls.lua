-- /qompassai/Diver/lsp/emmylua_ls.lua
-- Qompass AI Emmyluals Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

vim.lsp.config['emmylua_ls'] = {
	capabilities = vim.lsp.protocol.make_client_capabilities(),
	cmd = { 'emmylua_ls', '-c', 'stdio', '--log-level', 'info' },
	filetypes = { 'lua' },
	root_markers = { '.emmylua.json', '.luarc.json', '.luarc.json', '.luacheckrc' },
	flags = {
		debounce_text_changes = 150,
	},
	workspace_required = false,
	on_attach = function(client, bufnr)
		client.server_capabilities.documentFormattingProvider = false
		local opts = { buffer = bufnr, silent = true }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
		if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
			vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
			vim.lsp.inlay_hint(bufnr, true)
		end
	end,
	settings = {
		Emmylua = {
			completion = {
				callSnippet = "Replace",
				displayContext = 4,
				keywordSnippet = "Disable",
			},
			diagnostics = {
				disable = { "lowercase-global" },
				enable = true,
				globals = { "vim", "use", "require", "jit" },
				severity = { ["unused-local"] = "Hint" },
				unusedLocalExclude = { "_*" },
			},
			format = {
				defaultConfig = {
					align_continuous_assign_statement = true,
					indent_size = "2",
					indent_style = 'space',
					quote_style = "AutoPreferSingle",
					trailing_table_separator = "always",
				},
				enable = false,
			},
			hint = {
				arrayIndex = "Enable",
				await = true,
				enable = true,
				paramName = "All",
				paramType = true,
				setType = true,
			},
			runtime = {
				version = "LuaJIT",
			},
			telemetry = {
				enable = false,
			},
			workspace = {
				checkThirdParty = true,
				ignoreDir = { "node_modules", ".git", "build" },
				library = {
					vim.env.VIMRUNTIME,
					"${3rd}/busted/library",
					"${3rd}/luv/library",
					"${3rd}/luassert/library",
					"${3rd}/lazy.nvim/library",
					"${3rd}/neodev.nvim/types/nightly",
					"${3rd}/blink.cmp/library",
					"$HOME/.config/nvim/lua/types",
				},
				maxPreload = 1000,
				preloadFileSize = 10000,
			},
		},
	},
	single_file_support = true,
}
