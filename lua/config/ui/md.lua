-- /qompassai/Diver/lua/config/ui/md.lua
-- Qompass AI Diver Markdown Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

function M.md_anchor(link, opts)
	opts = opts or {}
	local prefix = opts.prefix or '#'
	local separator = opts.separator or '-'
	local lowercase = opts.lowercase ~= false
	local result = link
	if lowercase then
		result = string.lower(result)
	end
	return prefix .. result:gsub(' ', separator)
end

function M.md_autocmds()
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'markdown', 'md' },
		callback = function()
			vim.g.mkdp_auto_start = 0
			vim.g.mkdp_auto_close = 0
			vim.g.mkdp_refresh_slow = 1
			vim.g.mkdp_port = ''
			vim.g.mkdp_command_for_global = 0
			vim.g.mkdp_open_to_the_world = 0
			vim.g.mkdp_open_ip = ''
			vim.g.mkdp_combine_preview = 1
			vim.g.mkdp_browser = ''
			vim.g.mkdp_echo_preview_url = 1
			vim.g.mkdp_page_title = '${name}'
			vim.g.mkdp_filetypes = { 'markdown' }
			vim.g.mkdp_markdown_css = vim.fn.expand("$HOME/.config/nvim/markdown.css")
			vim.g.vim_markdown_folding_disabled = 1
			vim.g.vim_markdown_math = 1
			vim.g.vim_markdown_frontmatter = 1
			vim.g.vim_markdown_toml_frontmatter = 1
			vim.g.vim_markdown_json_frontmatter = 1
			vim.g.vim_markdown_follow_anchor = 1
			vim.opt_local.wrap = false
			vim.opt_local.conceallevel = 0
			vim.opt_local.concealcursor = 'nc'
			vim.opt_local.spell = true
			vim.opt_local.spelllang = 'en_us'
			vim.opt_local.textwidth = 120
		end,
	})
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'markdown', 'md' },
		callback = function()
			vim.keymap.set('n', '<leader>mp', ':MarkdownPreview<CR>', { buffer = true, desc = 'Markdown Preview' })
			vim.keymap.set('n', '<leader>ms', ':MarkdownPreviewStop<CR>', { buffer = true, desc = 'Stop Markdown Preview' })
			vim.keymap.set('n', '<leader>mt', ':TableModeToggle<CR>', { buffer = true, desc = 'Toggle Table Mode' })
			vim.keymap.set('n', '<leader>mi', ':KittyScrollbackGenerateImage<CR>', {
				buffer = true,
				desc = 'Generate image from code block',
			})
			vim.keymap.set('v', '<leader>mr', ':SnipRun<CR>', { buffer = true, desc = 'Run selected code' })
		end,
	})
	vim.api.nvim_create_user_command('MarkdownToPDF', function()
		local input_file = vim.fn.expand('%:p')
		local tex_file = vim.fn.expand('%:r') .. '.tex'
		local pdf_file = vim.fn.expand('%:r') .. '.pdf'
		vim.notify('Converting markdown to LaTeX...', vim.log.levels.INFO)
		local convert_cmd = 'pandoc ' .. input_file .. ' -o ' .. tex_file
		vim.fn.jobstart(convert_cmd, {
			on_exit = function(_, code)
				if code == 0 then
					vim.notify('Running lualatex...', vim.log.levels.INFO)
					vim.fn.jobstart('lualatex -interaction=nonstopmode ' .. tex_file, {
						on_exit = function(_, compile_code)
							if compile_code == 0 then
								vim.notify('PDF created: ' .. pdf_file, vim.log.levels.INFO)
							else
								vim.notify('lualatex failed to compile', vim.log.levels.ERROR)
							end
						end,
					})
				else
					vim.notify('Failed to convert Markdown to LaTeX', vim.log.levels.ERROR)
				end
			end,
		})
	end, {})
end

function M.md_conform(opts)
	require('config.lang.conform')
	opts = opts or {}
	local md_conform = {
		formatters_by_ft = { markdown = { 'biome' } },
		default_format_opts = { lsp_format = 'fallback', timeout_ms = 500 },
		format_on_save = { lsp_format = 'fallback', timeout_ms = 500 },
		log_level = vim.log.levels.ERROR,
		notify_on_error = true,
	}
	local config = vim.tbl_deep_extend('force', md_conform, opts)
	conform.setup(config)
	return config
end

function M.md_diagram(opts)
	opts = opts or {}
	require('diagram').setup({
			integrations = {
				require("diagram.integrations.markdown"),
				require("diagram.integrations.neorg"),
			},
			events = {
				render_buffer = { 'InsertLeave', 'BufWinEnter', 'TextChanged' },
				clear_buffer = { 'BufLeave' },
			},
			renderer_options = {
				mermaid = {
					background = nil,
					theme = 'dark',
					scale = 1,
					width = 800,
					height = 600,
				},
				plantuml = {
					charset = 'utf-8'
				},
				d2 = {
					theme_id = 'neutral',
					dark_theme_id = 'dark',
					scale = 1.0,
					layout = 'dagre',
					sketch = true,
					gnuplot = {
						size = nil,
						font = nil,
						theme = nil,
					},
				},
			},
		},
		vim.api.nvim_create_user_command('DiagramRender', function()
			require('diagram').render_buffer()
		end, {}))
	return opts
end

---@class Options
function M.md_image(opts)
	opts = opts or {}
	require('image').setup({
		backend = 'kitty',
		kitty_method = 'normal',
		processor = 'magick_cli',
		integrations = {
			markdown = {
				enabled = true,
				clear_in_insert_mode = true,
				download_remote_images = true,
				only_render_image_at_cursor = false,
				only_render_image_at_cursor_mode = 'inline',
				floating_windows = true,
				filetypes = { 'markdown', 'vimwiki', 'quarto' },
			},
			neorg = {
				enabled = true,
				clear_in_insert_mode = true,
				download_remote_images = true,
				only_render_image_at_cursor = false,
				filetypes = { 'norg' },
			},
			typst = {
				enabled = true,
				filetypes = { 'typst' },
			},
			html = {
				enabled = true,
				clear_in_insert_mode = true,
				download_remote_images = true,
				only_render_image_at_cursor = false,
				only_render_image_at_cursor_mode = 'inline',
				floating_windows = true,
			},
			css = {
				enabled = true,
				clear_in_insert_mode = true,
				download_remote_images = true,
				only_render_image_at_cursor = false,
				only_render_image_at_cursor_mode = 'inline',
				floating_windows = true,
			},
		},
		max_width = nil,
		max_height = nil,
		max_width_window_percentage = nil,
		max_height_window_percentage = 50,
		window_overlap_clear_enabled = true,
		window_overlap_clear_ft_ignore = {
			'cmp_menu',
			'cmp_docs',
			'scrollview',
			'scrollview_sign',
		},
		editor_only_render_when_focused = false,
		tmux_show_only_in_active_window = false,
		hijack_file_patterns = {
			'*.png',
			'*.jpg',
			'*.jpeg',
			'*.gif',
			'*.webp',
			'*.avif',
		},
	})
end

function M.nls(opts)
	opts = opts or {}
	local null_ls = require('null-ls')
	local sources = {
		null_ls.builtins.diagnostics.markdownlint,
		null_ls.builtins.diagnostics.markdownlint_cli2,
		null_ls.builtins.diagnostics.textlint,
		null_ls.builtins.diagnostics.write_good,
		null_ls.builtins.formatting.codespell,
	}
	return sources
end

function M.md_livepreview(opts)
	opts = vim.tbl_deep_extend('force', {
		port = 5500,
		browser = 'firefox', -- or 'default', 'vivaldi'
		dynamic_root = true,
		sync_scroll = true,
		picker = 'fzf-lua',
	}, opts or {})
	local ok, _ = pcall(require, 'live-preview')
	if not ok then
		vim.notify('live-preview.nvim not found', vim.log.levels.WARN)
		return
	end
	require('livepreview.config').set(opts)
end

function M.md_pdf(opts)
	opts = opts or {}
	require('md-pdf').setup({
		margins = opts.margins or '1.5cm',
		highlight = opts.highlight or 'tango',
		toc = opts.toc ~= false,
		preview_cmd = opts.preview_cmd,
		ignore_viewer_state = opts.ignore_viewer_state or false,
		fonts = opts.fonts or {
			main_font = nil,
			sans_font = 'DejaVuSans',
			mono_font = 'IosevkaTerm Nerd Font Mono',
			math_font = nil,
		},
		pandoc_user_args = opts.pandoc_user_args,
		output_path = opts.output_path or './',
		pdf_engine = opts.pdf_engine or 'lualatex',
	})
	local ok, md_pdf = pcall(require, 'md-pdf')
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'markdown', 'md' },
		callback = function()
			vim.keymap.set('n', '<leader>,', function()
				if ok and md_pdf and md_pdf.convert_md_to_pdf then
					md_pdf.convert_md_to_pdf()
				else
					vim.cmd('MarkdownToPDF')
				end
			end, { buffer = true, desc = 'Convert Markdown to PDF' })
		end,
	})
	return opts
end

function M.md_rendermd(opts)
	opts = opts or {}
	require('render-markdown').setup({
		enabled = true,
		render_modes = { 'n', 'c', 't' },
		max_file_size = 100.0,
		debounce = 100,
		preset = 'none',
		log_level = nil,
		log_runtime = false,
		file_types = { 'markdown' },
		ignore = function()
			return false
		end,
		change_events = {},
		injections = {
			gitcommit = {
				enabled = true,
				query = [[
          ((message) @injection.content
              (#set! injection.combined)
              (#set! injection.include-children)
              (#set! injection.language 'markdown'))
        ]],
			},
		},
		patterns = {
			markdown = {
				disable = false,
				directives = {
					{ id = 17, name = 'conceal_lines' },
					{ id = 18, name = 'conceal_lines' },
				},
			},
		},
		anti_conceal = {
			enabled = true,
			disabled_modes = true,
			above = 0,
			below = 0,
			ignore = {
				code_background = true,
				sign = true,
			},
		},
		padding = {
			highlight = 'Normal',
		},
		latex = {
			enabled = true,
			render_modes = true,
			converter = 'lualatex',
			highlight = 'RenderMarkdownMath',
			position = 'above',
			top_pad = 0,
			bottom_pad = 0,
		},
		on = {
			attach = function() end,
			initial = function() end,
			render = function() end,
			clear = function() end,
		},
		completions = {
			blink = {
				enabled = true
			},
			coq = {
				enabled = true
			},
			lsp = {
				enabled = false
			},
			filter = {
				callout = function()
					return true
				end,
				checkbox = function()
					return true
				end,
			},
		},
		heading = {
			enabled = false,
			render_modes = true,
			atx = true,
			setext = true,
			sign = true,
			icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
			position = 'overlay',
			signs = { '󰫎 ' },
			width = 'full',
			left_margin = 0,
			left_pad = 0,
			right_pad = 0,
			min_width = 0,
			border = true,
			border_virtual = true,
			border_prefix = true,
			above = '▄',
			below = '▀',
			backgrounds = {
				'RenderMarkdownH1Bg',
				'RenderMarkdownH2Bg',
				'RenderMarkdownH3Bg',
				'RenderMarkdownH4Bg',
				'RenderMarkdownH5Bg',
				'RenderMarkdownH6Bg',
			},
			foregrounds = {
				'RenderMarkdownH1',
				'RenderMarkdownH2',
				'RenderMarkdownH3',
				'RenderMarkdownH4',
				'RenderMarkdownH5',
				'RenderMarkdownH6',
			},
			custom = {},
		},
		paragraph = {
			enabled = true,
			render_modes = true,
			left_margin = 0,
			indent = 0,
			min_width = 0,
		},
		code = {
			enabled = true,
			render_modes = true,
			sign = true,
			style = 'full',
			position = 'left',
			language_pad = 0,
			language_icon = true,
			language_name = true,
			language_info = true,
			disable_background = { 'diff' },
			width = 'full',
			left_margin = 0,
			left_pad = 0,
			right_pad = 0,
			min_width = 0,
			border = 'hide',
			language_border = '█',
			language_left = '',
			language_right = '',
			above = '▄',
			below = '▀',
			inline_left = '',
			inline_right = '',
			inline_pad = 0,
			highlight = 'RenderMarkdownCode',
			highlight_info = 'RenderMarkdownCodeInfo',
			highlight_language = nil,
			highlight_border = 'RenderMarkdownCodeBorder',
			highlight_fallback = 'RenderMarkdownCodeFallback',
			highlight_inline = 'RenderMarkdownCodeInline',
		},
		dash = {
			enabled = true,
			render_modes = true,
			icon = '─',
			width = 'full',
			left_margin = 0,
			highlight = 'RenderMarkdownDash',
		},
		document = {
			enabled = true,
			render_modes = true,
			conceal = {
				char_patterns = {},
				line_patterns = {},
			},
		},
		bullet = {
			enabled = true,
			render_modes = true,
			icons = { '●', '○', '◆', '◇' },
			ordered_icons = function(ctx)
				local value = vim.trim(ctx.value)
				local index = tonumber(value:sub(1, #value - 1))
				return ('%d.'):format(index > 1 and index or ctx.index)
			end,
			left_pad = 0,
			right_pad = 0,
			highlight = 'RenderMarkdownBullet',
			scope_highlight = {},
		},
		checkbox = {
			enabled = true,
			render_modes = true,
			bullet = true,
			right_pad = 1,
			unchecked = {
				icon = '󰄱 ',
				highlight = 'RenderMarkdownUnchecked',
				scope_highlight = nil,
			},
			checked = {
				icon = '󰱒 ',
				highlight = 'RenderMarkdownChecked',
				scope_highlight = nil,
			},
			custom = {
				todo = { raw = '[-]', rendered = '󰥔 ', highlight = 'RenderMarkdownTodo', scope_highlight = nil },
			},
		},
		quote = {
			enabled = true,
			render_modes = true,
			icon = '▋',
			repeat_linebreak = true,
			highlight = {
				'RenderMarkdownQuote1',
				'RenderMarkdownQuote2',
				'RenderMarkdownQuote3',
				'RenderMarkdownQuote4',
				'RenderMarkdownQuote5',
				'RenderMarkdownQuote6',
			},
		},
		pipe_table = {
			enabled = true,
			render_modes = true,
			preset = 'none',
			style = 'full',
			cell = 'padded',
			padding = 1,
			min_width = 0,
			border = {
				'┌',
				'┬',
				'┐',
				'├',
				'┼',
				'┤',
				'└',
				'┴',
				'┘',
				'│',
				'─',
			},
			border_virtual = true,
			alignment_indicator = '━',
			head = 'RenderMarkdownTableHead',
			row = 'RenderMarkdownTableRow',
			filler = 'RenderMarkdownTableFill',
		},
		callout = {
			note = { raw = '[!NOTE]', rendered = '󰋽 Note', highlight = 'RenderMarkdownInfo', category = 'github' },
			tip = { raw = '[!TIP]', rendered = '󰌶 Tip', highlight = 'RenderMarkdownSuccess', category = 'github' },
			important = {
				raw = '[!IMPORTANT]',
				rendered = '󰅾 Important',
				highlight = 'RenderMarkdownHint',
				category = 'github',
			},
			warning = { raw = '[!WARNING]', rendered = '󰀪 Warning', highlight = 'RenderMarkdownWarn', category = 'github' },
			caution = {
				raw = '[!CAUTION]',
				rendered = '󰳦 Caution',
				highlight = 'RenderMarkdownError',
				category = 'github',
			},
			abstract = {
				raw = '[!ABSTRACT]',
				rendered = '󰨸 Abstract',
				highlight = 'RenderMarkdownInfo',
				category = 'obsidian',
			},
			summary = {
				raw = '[!SUMMARY]',
				rendered = '󰨸 Summary',
				highlight = 'RenderMarkdownInfo',
				category = 'obsidian',
			},
			tldr = { raw = '[!TLDR]', rendered = '󰨸 Tldr', highlight = 'RenderMarkdownInfo', category = 'obsidian' },
			info = { raw = '[!INFO]', rendered = '󰋽 Info', highlight = 'RenderMarkdownInfo', category = 'obsidian' },
			todo = { raw = '[!TODO]', rendered = '󰗡 Todo', highlight = 'RenderMarkdownInfo', category = 'obsidian' },
			hint = { raw = '[!HINT]', rendered = '󰌶 Hint', highlight = 'RenderMarkdownSuccess', category = 'obsidian' },
			success = {
				raw = '[!SUCCESS]',
				rendered = '󰄬 Success',
				highlight = 'RenderMarkdownSuccess',
				category = 'obsidian',
			},
			check = { raw = '[!CHECK]', rendered = '󰄬 Check', highlight = 'RenderMarkdownSuccess', category = 'obsidian' },
			done = { raw = '[!DONE]', rendered = '󰄬 Done', highlight = 'RenderMarkdownSuccess', category = 'obsidian' },
			question = {
				raw = '[!QUESTION]',
				rendered = '󰘥 Question',
				highlight = 'RenderMarkdownWarn',
				category = 'obsidian',
			},
			help = { raw = '[!HELP]', rendered = '󰘥 Help', highlight = 'RenderMarkdownWarn', category = 'obsidian' },
			faq = { raw = '[!FAQ]', rendered = '󰘥 Faq', highlight = 'RenderMarkdownWarn', category = 'obsidian' },
			attention = {
				raw = '[!ATTENTION]',
				rendered = '󰀪 Attention',
				highlight = 'RenderMarkdownWarn',
				category = 'obsidian',
			},
			failure = {
				raw = '[!FAILURE]',
				rendered = '󰅖 Failure',
				highlight = 'RenderMarkdownError',
				category = 'obsidian',
			},
			fail = { raw = '[!FAIL]', rendered = '󰅖 Fail', highlight = 'RenderMarkdownError', category = 'obsidian' },
			missing = {
				raw = '[!MISSING]',
				rendered = '󰅖 Missing',
				highlight = 'RenderMarkdownError',
				category = 'obsidian',
			},
			danger = { raw = '[!DANGER]', rendered = '󱐌 Danger', highlight = 'RenderMarkdownError', category = 'obsidian' },
			error = { raw = '[!ERROR]', rendered = '󱐌 Error', highlight = 'RenderMarkdownError', category = 'obsidian' },
			bug = { raw = '[!BUG]', rendered = '󰨰 Bug', highlight = 'RenderMarkdownError', category = 'obsidian' },
			example = {
				raw = '[!EXAMPLE]',
				rendered = '󰉹 Example',
				highlight = 'RenderMarkdownHint',
				category = 'obsidian',
			},
			quote = { raw = '[!QUOTE]', rendered = '󱆨 Quote', highlight = 'RenderMarkdownQuote', category = 'obsidian' },
			cite = { raw = '[!CITE]', rendered = '󱆨 Cite', highlight = 'RenderMarkdownQuote', category = 'obsidian' },
		},
		link = {
			enabled = true,
			render_modes = true,
			footnote = {
				enabled = true,
				superscript = true,
				prefix = '',
				suffix = '',
			},
			image = '󰥶 ',
			email = '󰀓 ',
			hyperlink = '󰌹 ',
			highlight = 'RenderMarkdownLink',
			wiki = {
				icon = '󱗖 ',
				body = function()
					return nil
				end,
				highlight = 'RenderMarkdownWikiLink',
			},
			custom = {
				web = { pattern = '^http', icon = '󰖟 ' },
				discord = { pattern = 'discord%.com', icon = '󰙯 ' },
				github = { pattern = 'github%.com', icon = '󰊤 ' },
				gitlab = { pattern = 'gitlab%.com', icon = '󰮠 ' },
				google = { pattern = 'google%.com', icon = '󰊭 ' },
				neovim = { pattern = 'neovim%.io', icon = ' ' },
				reddit = { pattern = 'reddit%.com', icon = '󰑍 ' },
				stackoverflow = { pattern = 'stackoverflow%.com', icon = '󰓌 ' },
				wikipedia = { pattern = 'wikipedia%.org', icon = '󰖬 ' },
				youtube = { pattern = 'youtube%.com', icon = '󰗃 ' },
			},
		},
		sign = {
			enabled = true,
			highlight = 'RenderMarkdownSign',
		},
		inline_highlight = {
			enabled = true,
			render_modes = true,
			highlight = 'RenderMarkdownInlineHighlight',
		},
		indent = {
			enabled = true,
			render_modes = true,
			per_level = 2,
			skip_level = 1,
			skip_heading = true,
			icon = '▎',
			highlight = 'RenderMarkdownIndent',
		},
		html = {
			enabled = true,
			render_modes = true,
			comment = {
				conceal = false,
				text = nil,
				highlight = 'RenderMarkdownHtmlComment',
			},
			tag = {},
		},
		win_options = {
			conceallevel = {
				default = vim.o.conceallevel,
				rendered = 3,
			},
			concealcursor = {
				default = vim.o.concealcursor,
				rendered = '',
			},
		},
		overrides = {
			-- More granular configuration mechanism, allows different aspects of buffers to have their own
			-- behavior. Values default to the top level configuration if no override is provided. Supports
			-- the following fields:
			--   enabled, max_file_size, debounce, render_modes, anti_conceal, padding, heading, paragraph,
			--   code, dash, bullet, checkbox, quote, pipe_table, callout, link, sign, indent, latex, html,
			--   win_options
			buflisted = {},
			buftype = {
				nofile = {
					render_modes = true,
					padding = { highlight = 'NormalFloat' },
					sign = { enabled = true },
				},
			},
			filetype = {},
		},
		custom_handlers = {},
	})
	return opts
end

function M.md_treesitter(opts)
	opts = opts or {}
	opts.sync_install = opts.sync_install or true
	opts.ignore_install = opts.ignore_install or {}
	opts.auto_install = opts.auto_install ~= false
	opts.modules = opts.modules or {}
	opts.ensure_installed = opts.ensure_installed or {}
	opts.highlight = opts.highlight or {}
	opts.highlight.enable = opts.highlight.enable ~= false
	opts.highlight.additional_vim_regex_highlighting = opts.highlight.additional_vim_regex_highlighting or { 'markdown' }
	require('nvim-treesitter.configs').setup(opts)
end

function M.md_table_mode()
	vim.g.table_mode_corner = '|'
	vim.g.table_mode_separator = '|'
	vim.g.table_mode_always_active = 1
	vim.g.table_mode_syntax = 1
	vim.g.table_mode_update_time = 300
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'markdown', 'md' },
		callback = function()
			vim.cmd('TableModeEnable')
		end,
	})
end

function M.md_latex_preview()
	local nabla_ok, nabla = pcall(require, 'nabla')
	if nabla_ok then
		vim.keymap.set('n', '<leader>mp', function()
			nabla.popup()
		end, { desc = 'Preview LaTeX equations' })

		vim.keymap.set('n', '<leader>mt', function()
			nabla.toggle_virt()
		end, { desc = 'Toggle LaTeX equations' })
	end
end

function M.md_config(opts)
	opts = opts or {}
	M.md_anchor(opts)
	M.md_autocmds()
	M.md_conform(opts)
	M.md_lsp(opts.on_attach, opts.capabilities)
	local null_ls_ok, null_ls = pcall(require, 'null-ls')
	if null_ls_ok then
		local sources = M.nls(opts)
		if #sources > 0 then
			for _, source in ipairs(sources) do
				null_ls.register(source)
			end
		end
	end
	M.md_image(opts)
	M.md_livepreview(opts)
	M.nls(opts)
	M.md_treesitter(opts)
	M.md_preview(opts)
	M.md_rendermd(opts)
	M.md_pdf(opts)
end

return M
