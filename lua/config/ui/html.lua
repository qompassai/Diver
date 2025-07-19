-- /qompassai/Diver/lua/config/ui/html.lua
-- Qompass AI Diver HTML Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

function M.html_autotag(opts)
	opts = opts or {}
	require('nvim-ts-autotag').setup({
		opts = {
			enable_close = true,
			enable_rename = true,
			enable_close_on_slash = true,
		},
		per_filetype = {
			["html"] = {
				enable_close = true,
			},
		},
	})
	return opts
end

function M.nls(opts)
	opts = opts or {}
	local nlsb = require('null-ls').builtins
	local utils = require('null-ls.utils')
	local biome_config_path = vim.fn.expand('$HOME/.config/biome/biome.json')
	local biome_args = { 'format', '--stdin-file-path', '$FILENAME' }
	if biome_config_path then
		table.insert(biome_args, '--config-path')
		table.insert(biome_args, biome_config_path)
	end
	return {
		nlsb.formatting.biome.with({
			filetypes = { 'html' },
			extra_args = biome_args,
			runtime_condition = function()
				return utils.executable('biome')
			end,
		}),
		nlsb.diagnostics.djlint.with({
			filetypes = { 'html', 'htmldjango', 'blade' },
			condition = function()
				return utils.executable('djlint')
			end,
		}),
		nlsb.diagnostics.tidy.with({
			filetypes = { 'html' },
			extra_args = { '-errors', '-q' },
			condition = function()
				return utils.executable('tidy')
			end,
		}),
	}
end

function M.html_emmet(opts)
	opts = opts or {}
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'html' },
		callback = function()
			vim.bo.omnifunc = 'v:lua.vim.lsp.omnifunc'
			vim.keymap.set('i', '<C-e>', '<C-y>,', { buffer = true, desc = 'Emmet expand abbreviation' })
		end,
	})
end

function M.html_lsp(opts)
	opts = opts or {}
	opts = ({
		on_attach = opts.on_attach,
		capabilities = opts.capabilities,
		filetypes = { 'html', 'handlebars', 'htmldjango', 'blade', 'erb', 'ejs' },
		init_options = {
			configurationSection = { 'html', 'css' },
			embeddedLanguages = {
				css = true,
				javascript = true
			},
			provideFormatter = true,
		},
	})
	return opts
end

function M.emmet_ls(opts)
	opts = opts or {}
	opts.emmet_ls.setup({
		on_attach = opts.on_attach,
		capabilities = opts.capabilities,
		filetypes = {
			'html',
			'javascriptreact',
			'typescriptreact',
			'haml',
			'xml',
			'xsl',
			'pug',
			'slim',
			'erb',
			'vue',
			'svelte',
		},
	})
	return opts
end

function M.html_cmp()
	if vim.g.use_blink_cmp then
		local blink = require('blink')
		local htmx_items = {
			{ label = "hx-get",       insertText = 'hx-get="${1:url}"',            kind = "Property" },
			{ label = "hx-post",      insertText = 'hx-post="${1:url}"',           kind = "Property" },
			{ label = "hx-put",       insertText = 'hx-put="${1:url}"',            kind = "Property" },
			{ label = "hx-delete",    insertText = 'hx-delete="${1:url}"',         kind = "Property" },
			{ label = "hx-trigger",   insertText = 'hx-trigger="${1:event}"',      kind = "Property" },
			{ label = "hx-swap",      insertText = 'hx-swap="${1:innerHTML}"',     kind = "Property" },
			{ label = "hx-target",    insertText = 'hx-target="${1:selector}"',    kind = "Property" },
			{ label = "hx-select",    insertText = 'hx-select="${1:selector}"',    kind = "Property" },
			{ label = "hx-confirm",   insertText = 'hx-confirm="${1:message}"',    kind = "Property" },
			{ label = "hx-indicator", insertText = 'hx-indicator="${1:selector}"', kind = "Property" },
		}
		local config = {
			sources = {
				{ name = 'lsp' },
				{ name = 'luasnip' },
				{ name = 'path' },
				{ name = 'buffer', keyword_length = 3 },
				{
					name = "static",
					option = {
						items = htmx_items,
						filetypes = { "html" },
					},
				},
			},
			performance = {
				async = true,
				throttle = 50
			},
			appearance = {
				kind_icons = require('lazyvim.config').icons.kinds,
				nerd_font_variant = 'mono',
				use_nvim_cmp_as_default = false,
			},
			completion = {
				accept = {
					auto_brackets = true
				},
				menu = {
					draw = {
						treesitter = {
							'lsp'
						}
					}
				},
				documentation = { auto_show = true },
			}
		}
		blink.setup(config)
		return config
	else
		return {
			snippet = {
				expand = function(args)
					local luasnip = require('luasnip')
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = require('cmp').mapping.preset.insert({
				['<C-b>'] = require('cmp').mapping.scroll_docs(-4),
				['<C-f>'] = require('cmp').mapping.scroll_docs(4),
				['<C-Space>'] = require('cmp').mapping.complete(),
				['<C-e>'] = require('cmp').mapping.abort(),
				['<CR>'] = require('cmp').mapping.confirm({ select = true }),
			}),
			sources = {
				{ name = 'nvim_lua' },
				{ name = 'nvim_lsp' },
				{ name = 'luasnip' },
				{ name = 'buffer' },
				{
					name = "static",
					option = {
						items = {
							{ label = "hx-get",       insertText = 'hx-get="${1:url}"',            kind = "Property" },
							{ label = "hx-post",      insertText = 'hx-post="${1:url}"',           kind = "Property" },
							{ label = "hx-put",       insertText = 'hx-put="${1:url}"',            kind = "Property" },
							{ label = "hx-delete",    insertText = 'hx-delete="${1:url}"',         kind = "Property" },
							{ label = "hx-trigger",   insertText = 'hx-trigger="${1:event}"',      kind = "Property" },
							{ label = "hx-swap",      insertText = 'hx-swap="${1:innerHTML}"',     kind = "Property" },
							{ label = "hx-target",    insertText = 'hx-target="${1:selector}"',    kind = "Property" },
							{ label = "hx-select",    insertText = 'hx-select="${1:selector}"',    kind = "Property" },
							{ label = "hx-confirm",   insertText = 'hx-confirm="${1:message}"',    kind = "Property" },
							{ label = "hx-indicator", insertText = 'hx-indicator="${1:selector}"', kind = "Property" },
						},
						filetypes = { "html" },
					},
				},
			},
			experimental = { ghost_text = true },
			performance = { async = true, throttle = 50 },
			appearance = {
				kind_icons = require('lazyvim.config').icons.kinds,
				nerd_font_variant = 'mono',
				use_nvim_cmp_as_default = false,
			},
			completion = {
				accept = { auto_brackets = true },
				menu = { draw = { treesitter = { 'lsp' } } },
				documentation = { auto_show = true },
			}
		}
	end
end

function M.html_conform(opts)
	opts = opts or {}
	local conform_cfg = require('config.lang.conform')
	return {
		formatters_by_ft = {
			html = { 'biome' },
			htmldjango = { 'biome' },
			blade = { 'blade-formatter' },
		},
		format_on_save = conform_cfg.format_on_save,
		format_after_save = conform_cfg.format_after_save,
		default_format_opts = conform_cfg.default_format_opts,
	}
end

function M.html_treesitter(opts)
	opts = opts or {}
	opts = {
		highlight = { enable = true },
		indent = { enable = true },
	}
end

function M.html_cfg(opts)
	opts = opts or {}
	autotag = M.html_autotag(opts)
	cmp = M.html_cmp()
	lsp = M.html_lsp(opts)
	nls = M.nls(opts)
	treesitter = M.html_treesitter(opts)
	emmet = M.html_emmet(opts)
	conform = M.html_conform(opts)
end

return M
