-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['lua_ls'] = {
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
					path ~= vim.fn.stdpath('config')
					and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.json5'))
			then
				return
			end
		end
	end,
	cmd = { 'lua-language-server' },
	codeActionProvider = {
		codeActionKinds = { "", "quickfix", "refactor.rewrite", "refactor.extract" },
		resolveProvider = true
	},
	colorProvider = true,
	filetypes = { 'lua', 'luau' },
	semanticTokensProvider = {
		full = true,
		legend = {
			tokenModifiers = { "declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary", "global" },
			tokenTypes = { "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator", "decorator" }
		},
		range = true
	},
	--	root_markers = { '.luarc.json', '.luarc.jsonc', ".luarc.json5", '.stylua.toml', 'luacheckrc', '.luacheckrc' },
	settings = {
		Lua = {
			format = {
				enable = true,
				defaultConfig = {
					align_continuous_rect_table_field = true,
					align_array_table = true,
					indent_style = "space",
					indent_size = "2",
					quote_style = 'AutoPreferSingle',
					trailing_table_separator = "always",
					align_continuous_assign_statement = true,
				},
			},
			runtime = {
				version = "LuaJIT",
				path = {
					'lua/?.lua',
					'lua/?/init.lua',
				},
			},
			diagnostics = {
				enable = true,
				globals = { "vim", "jit", "use", "require" },
				disable = { "lowercase-global" },
				severity = { ["unused-local"] = "Hint" },
				unusedLocalExclude = { "_*" },
			},
			workspace = {
				checkThirdParty = true,
				library = {
					vim.api.nvim_get_runtime_file('', true),
					vim.env.VIMRUNTIME,
					"${3rd}/luv/library",
					"${3rd}/busted/library",
					"${3rd}/neodev.nvim/types/nightly",
					"${3rd}/luassert/library",
					"${3rd}/lazy.nvim/library",
					"${3rd}/blink.cmp/library",
					"$HOME/.config/nvim/lua/types",
				},
				ignoreDir = { "node_modules", "build" },
				maxPreload = 2000,
				preloadFileSize = 50000,
			},
			telemetry = {
				enable = false,
			},
			completion = {
				callSnippet = "Replace",
				keywordSnippet = "Disable",
				displayContext = 4,
			},
			hint = {
				enable = true,
				setType = true,
				paramType = true,
				paramName = "All",
				arrayIndex = "Enable",
				await = true,
			},
		},
	},
	capabilities = vim.lsp.protocol.make_client_capabilities(),
	on_attach = function(client, bufnr)
		local opts = { buffer = bufnr, silent = true }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
		if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
			vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
			vim.lsp.inlay_hint(bufnr, true)
		end
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = bufnr,
			callback = function() vim.lsp.buf.format({ async = false }) end,
		})
	end,
	flags = {
		debounce_text_changes = 150,
	},
	single_file_support = true,
}
