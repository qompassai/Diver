-- /qompassai/Diver/lua/config/ui/html.lua
-- Qompass AI Diver HTML Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
local function find_biome_config()
	local uv = vim.loop
	local config_files = { "biome.json", "biome.jsonc", "biome.json5" }
	local dir = vim.fn.expand("%:p:h")
	while dir and dir ~= "/" do
		for _, fname in ipairs(config_files) do
			local path = dir .. "/" .. fname
			if uv.fs_stat(path) then
				return path
			end
		end
		dir = dir:match("(.+)/[^/]+$")
	end
	local xdg = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	for _, fname in ipairs(config_files) do
		local path = xdg .. "/biome/" .. fname
		if uv.fs_stat(path) then
			return path
		end
	end
	return nil
end

function M.html_cmp(opts)
	opts = opts or {}
	local blink = require("blink.cmp")
	local htmx_items = opts.htmx_items
		or {
			{ label = "hx-get", insertText = 'hx-get="${1:url}"', kind = "Property" },
			{ label = "hx-post", insertText = 'hx-post="${1:url}"', kind = "Property" },
			{ label = "hx-put", insertText = 'hx-put="${1:url}"', kind = "Property" },
			{ label = "hx-delete", insertText = 'hx-delete="${1:url}"', kind = "Property" },
			{ label = "hx-trigger", insertText = 'hx-trigger="${1:event}"', kind = "Property" },
			{ label = "hx-swap", insertText = 'hx-swap="${1:innerHTML}"', kind = "Property" },
			{ label = "hx-target", insertText = 'hx-target="${1:selector}"', kind = "Property" },
			{ label = "hx-select", insertText = 'hx-select="${1:selector}"', kind = "Property" },
			{ label = "hx-confirm", insertText = 'hx-confirm="${1:message}"', kind = "Property" },
			{ label = "hx-indicator", insertText = 'hx-indicator="${1:selector}"', kind = "Property" },
		}
	local filetypes = opts.filetypes or { "html" }
	local sources = opts.sources
		or {
			{ name = "luasnip" },
			{ name = "lsp" },
			{ name = "path" },
			{ name = "buffer", keyword_length = 3 },
			{
				name = "static",
				option = {
					items = htmx_items,
					filetypes = filetypes,
				},
			},
		}
	blink.setup({
		sources = sources,
	})
end
function M.html_nls(opts)
	opts = opts or {}
	local nls = require("null-ls")
	local nlsb = nls.builtins
	local utils = require("null-ls.utils")
	local biome_config_path = find_biome_config()
	local biome_args = { "format", "--stdin-file-path", "$FILENAME" }
	if biome_config_path then
		table.insert(biome_args, "--config-path")
		table.insert(biome_args, biome_config_path)
	end
	return {
		nlsb.formatting.biome.with({
			filetypes = { "html" },
			extra_args = biome_args,
			runtime_condition = function()
				return utils.executable("biome")
			end,
		}),
		nlsb.diagnostics.djlint.with({
			filetypes = { "html", "htmldjango", "blade" },
			condition = function()
				return utils.executable("djlint")
			end,
		}),
		nlsb.diagnostics.tidy.with({
			filetypes = { "html" },
			extra_args = { "-errors", "-q" },
			condition = function()
				return utils.executable("tidy")
			end,
		}),
	}
end

function M.html_emmet(opts)
	opts = opts or {}
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "html" },
		callback = function()
			vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"
			vim.keymap.set("i", "<C-e>", "<C-y>,", { buffer = true, desc = "Emmet expand abbreviation" })
		end,
	})
end

function M.html_lsp(opts)
	opts = opts or {}
	local lsp = require("lspconfig")
	lsp.html.setup({
		on_attach = opts.on_attach,
		capabilities = opts.capabilities,
		filetypes = { "html", "handlebars", "htmldjango", "blade", "erb", "ejs" },
		init_options = {
			configurationSection = { "html", "css" },
			embeddedLanguages = { css = true, javascript = true },
			provideFormatter = true,
		},
	})
	lsp.emmet_ls.setup({
		on_attach = opts.on_attach,
		capabilities = opts.capabilities,
		filetypes = {
			"html",
			"javascriptreact",
			"typescriptreact",
			"haml",
			"xml",
			"xsl",
			"pug",
			"slim",
			"erb",
			"vue",
			"svelte",
		},
	})
	return opts
end
function M.html_preview(opts)
	opts = opts or {}
	local livepreview = require("livepreview.config")
	livepreview.set(vim.tbl_extend("force", {
		port = 8090,
		browser_cmd = "firefox",
		auto_start = true,
		refresh_delay = 150,
		allowed_file_types = { "html", "markdown", "asciidoc", "svg" },
	}, opts))
end
function M.html_conform(opts)
	opts = opts or {}
	local conform_cfg = require("config.lang.conform")
	return {
		formatters_by_ft = {
			html = { "biome" },
			htmldjango = { "biome" },
			blade = { "blade-formatter" },
		},
		format_on_save = conform_cfg.format_on_save,
		format_after_save = conform_cfg.format_after_save,
		default_format_opts = conform_cfg.default_format_opts,
	}
end

function M.html_treesitter(opts)
	opts = opts or {}
	return {
		highlight = { enable = true },
		indent = { enable = true },
	}
end

function M.html_cfg(opts)
	opts = opts or {}
	return {
		cmp = M.html_cmp(opts),
		nls = M.html_nls(opts),
		lsp = function(lsp_opts)
			M.html_lsp(vim.tbl_extend("force", opts, lsp_opts or {}))
		end,
		treesitter = M.html_treesitter(opts),
		emmet = M.html_emmet(opts),
		preview = M.html_preview(opts),
		conform = M.html_conform(opts),
	}
end
return M
