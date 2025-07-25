-- /qompassai/Diver/lsp/pyright.lua
-- Qompass AI Python LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['pyright'] = {
	cmd = { 'pyright-langserver', "--stdio" },
	filetypes = { 'python' },
	handlers = {
		["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
	},
	root_markers = {
		"pyproject.toml", "setup.py", "setup.cfg", "requirements.txt",
		"Pipfile", "pyrightconfig.json",
	},
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				autoImportCompletions = true,
				extraPaths = { "./src", "./lib" },
				stubPath = "typings",
				typeCheckingMode = "strict",
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
		vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
		if client.server_capabilities.inlayHintProvider and type(vim.lsp.inlay_hint) == "function" then
			vim.lsp.inlay_hint(bufnr, true)
		end
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = bufnr,
			callback = function() vim.lsp.buf.format({ async = false }) end,
		})
	end,
	flags = { debounce_text_changes = 150 },
	single_file_support = true,
}
