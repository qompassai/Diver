-- /qompassai/Diver/lsp/emmylua_ls.lua
-- Qompass AI Emmyluals Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local function get_luajit_dir()
	local luajit_path = vim.fn.exepath('luajit')
	if luajit_path ~= "" then
		return vim.fn.fnamemodify(luajit_path, ":h")
	end
	return nil
end


local luajit_dir = get_luajit_dir()
local runtime_paths = vim.split(package.path, ";")
if luajit_dir then
	table.insert(runtime_paths, 1, luajit_dir)
end
local util = require('lspconfig.util')
vim.lsp.config['emmylua_ls'] = {
	capabilities = vim.lsp.protocol.make_client_capabilities(),
	cmd = { 'emmylua_ls' },
	filetypes = { "lua" },
	root_dir = util.root_pattern('.emmylua.json', '.luarc.json', '.luacheckrc', '.git'),
	flags = {
		debounce_text_changes = 150,
	},
	handlers = {
		["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
	},
	on_attach = function(client, bufnr)
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
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = bufnr,
			callback = function() vim.lsp.buf.format({ async = true }) end,
		})
	end,
	root_markers = { '.emmylua.json', '.luarc.json', '.luacheckrc', '.git' },
	settings = {
		Emmylua = {
			completion = {
				callSnippet = "Replace",
				displayContext = 3,
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
				enable = true,
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
				path = runtime_paths,
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
