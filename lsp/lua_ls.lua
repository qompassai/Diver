-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Lua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
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

vim.lsp.config['lua_ls'] = {
	cmd = { "lua-language-server" },
	filetypes = { "lua", "luau" },
	handlers = {
		["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
	},
	root_markers = { ".luarc.json", ".luarc.jsonc", ".luarc.json5", ".git" },
	settings = {
		Lua = {
			format = {
				enable = true,
				defaultConfig = {
					indent_style = "space",
					indent_size = "2",
					quote_style = "single",
					trailing_table_separator = "always",
					align_continuous_assign_statement = true,
				},
			},
			runtime = {
				version = "LuaJIT",
				path = runtime_paths,
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
					vim.env.VIMRUNTIME,
					"${3rd}/luv/library",
					"${3rd}/busted/library",
					"${3rd}/neodev.nvim/types/nightly",
					"${3rd}/luassert/library",
					"${3rd}/lazy.nvim/library",
					"${3rd}/blink.cmp/library",
					"$HOME/.config/nvim/lua/types"
				},
				ignoreDir = { "node_modules", ".git", "build" },
				maxPreload = 2000,
				preloadFileSize = 50000,
			},
			telemetry = {
				enable = false,
			},
			completion = {
				callSnippet = "Replace",
				keywordSnippet = "Disable",
				displayContext = 3,
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
	capabilities = require("blink.cmp").get_lsp_capabilities(),
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
