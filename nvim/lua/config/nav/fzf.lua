-- /qompassai/Diver/lua/config/nav/fzf.lua
-- Qompass AI Diver Nav Fzf Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn

M.keymaps = {
	builtin = {
		['<M-Esc>'] = 'hide',
		['<F1>'] = 'toggle-help',
		['<F2>'] = 'toggle-fullscreen',
		['<F3>'] = 'toggle-preview-wrap',
		['<F4>'] = 'toggle-preview',
		['<F5>'] = 'toggle-preview-cw',
		['<F6>'] = 'toggle-preview-behavior',
		['<F7>'] = 'toggle-preview-ts-ctx',
		['<F8>'] = 'preview-ts-ctx-dec',
		['<F9>'] = 'preview-ts-ctx-inc',
		['<S-Left>'] = 'preview-reset',
		['<S-down>'] = 'preview-page-down',
		['<S-up>'] = 'preview-page-up',
		['<M-S-down>'] = 'preview-down',
		['<M-S-up>'] = 'preview-up',
	},
	{
		'<leader>zb',
		'<cmd>FzfLua buffers<cr>',
		desc = 'Fzf Buffers',
	},
	{
		'<leader>zc',
		'<cmd>FzfLua commands<cr>',
		desc = 'Fzf Commands',
	},
	{
		'<leader>zd',
		'<cmd>FzfLua lsp_document_symbols<cr>',
		desc = 'Fzf Document Symbols',
	},
	{
		'<leader>zf',
		'<cmd>FzfLua files<cr>',
		desc = 'Fzf Files',
	},
	{
		'<leader>zgb',
		'<cmd>FzfLua git_branches<cr>',
		desc = 'Fzf Git Branches',
	},
	{
		'<leader>zgs',
		'<cmd>FzfLua git_status<cr>',
		desc = 'Fzf Git Status',
	},
	{
		'<leader>zh',
		'<cmd>FzfLua help_tags<cr>',
		desc = 'Fzf Help Tags',
	},
	{
		'<leader>zH',
		'<cmd>FzfLua colorschemes<cr>',
		desc = 'Fzf Colorscheme',
	},
	{
		'<leader>zm',
		'<cmd>FzfLua marks<cr>',
		desc = 'Fzf Marks',
	},
	{
		'<leader>zs',
		'<cmd>FzfLua live_grep<cr>',
		desc = 'Fzf Search',
	},
	{
		'<leader>zWs',
		'<cmd>FzfLua lsp_live_workspace_symbols<cr>',
		desc = 'Fzf Workspace Symbols',
	},
	{
		'<leader>zw',
		'<cmd>FzfLua grep_cword<cr>',
		desc = 'Fzf Current Word',
	},
}

M.options = {
	actions = {},
	files = {
		previewer = 'bat',
		prompt = 'Files❯ ',
		cmd = 'rg --files',
		find_opts = [[-type f \! -path '*/.git/*']],
		rg_opts = [[--color=never --hidden --files -g "!.git"]],
		fd_opts = [[--color=never --hidden --type f --type l --exclude .git]],
		dir_opts = [[/s/b/a:-d]],
		cwd_prompt = true,
		cwd_prompt_shorten_len = 32,
		cwd_prompt_shorten_val = 1,
		toggle_ignore_flag = '--no-ignore',
		toggle_hidden_flag = '--hidden',
		toggle_follow_flag = '-L',
		hidden = true,
		follow = false,
		no_ignore = false,
		absolute_path = false,
		zoxide = {
			cmd = 'zoxide query --list --score',
			scope = 'global',
			git_root = true,
			formatter = 'path.dirname_first',
			fzf_opts = {
				['--no-multi'] = true,
				['--delimiter'] = '[\t]',
				['--tabstop'] = '4',
				['--tiebreak'] = 'end,index',
				['--nth'] = '2..',
			},
		},
	},
	fzf_bin = 'sk',
	fzf_colors = {
		true,
		['bg'] = {
			'bg',
			'Normal',
		},
		['bg+'] = {
			'bg',
			{
				'CursorLine',
				'Normal',
			},
		},
		['fg'] = {
			'fg',
			'CursorLine',
		},
		['fg+'] = {
			'fg',
			'Normal',
			'underline',
		},
		['gutter'] = '-1',
		['header'] = {
			'fg',
			'Comment',
		},
		['hl'] = {
			'fg',
			'Comment',
		},
		['hl+'] = {
			'fg',
			'Statement',
		},
		['info'] = {
			'fg',
			'PreProc',
		},
		['marker'] = {
			'fg',
			'Keyword',
		},
		['pointer'] = {
			'fg',
			'Exception',
		},
		['prompt'] = {
			'fg',
			'Conditional',
		},
		['spinner'] = {
			'fg',
			'Label',
		},
	},
	fzf_opts = {
		['--algo'] = 'frizbee',
		['--ansi'] = true,
		['--border'] = 'none',
		['--height'] = '100%',
		['--highlight-line'] = true,
		['--info'] = 'inline-right',
		['--layout'] = 'reverse',
	},
	fzf_tmux_opts = {
		['--margin'] = '0,0',
		['-p'] = '80%,80%',
	},
	hls = {
		normal = 'Normal',
		preview_normal = 'Normal',
	},
	keymap = {
		fzf = {
			['ctrl-c'] = 'abort',
			['ctrl-d'] = 'half-page-down',
			['ctrl-q'] = 'select-all+accept',
			['ctrl-u'] = 'half-page-up',
		},
	},
	winopts = {
		border = 'rounded',
		height = 0.85,
		hls = {
			Border = 'FloatBorder',
			Normal = 'Normal',
		},
		preview = {
			default = 'bat',
			hidden = 'hidden',
			layout = 'flex',
			vertical = 'down:45%',
		},
		width = 0.85,
	},
}

---@return string[]
local function project_directories()
	local root = fn.expand('~/projects')
	if fn.isdirectory(root) ~= 1 then
		return {}
	end

	if fn.executable('fd') == 1 then
		return fn.systemlist({
			'fd',
			'--type',
			'd',
			'--max-depth',
			'2',
			'--absolute-path',
			'.',
			root,
		})
	end

	return fn.systemlist({
		'find',
		root,
		'-maxdepth',
		'2',
		'-type',
		'd',
	})
end

function M.fzf_setup()
	local fzf = require('fzf-lua')

	fzf.setup(M.options)
	fzf.register_ui_select()

	api.nvim_create_user_command('Projects', function()
		local projects = project_directories()
		if #projects == 0 then
			vim.notify('Projects: no directories found under ~/projects', vim.log.levels.INFO)
			return
		end

		fzf.fzf_exec(projects, {
			actions = {
				---@param selected string[]
				['default'] = function(selected)
					local directory = selected[1]
					if directory == nil or directory == '' then
						return
					end

					api.nvim_set_current_dir(directory)
					fzf.files({
						cwd = directory,
					})
				end,
			},
			prompt = 'Projects> ',
		})
	end, {
		force = true,
	})
end

---@param lines string[]
---@param sink fun(selection: string)
local function fzf_pick(lines, sink)
	if #lines == 0 then
		vim.notify('fzf: no entries', vim.log.levels.INFO)
		return
	end

	local executable = M.options.fzf_bin
	if fn.executable(executable) ~= 1 then
		executable = 'fzf'
	end

	if fn.executable(executable) ~= 1 then
		vim.notify('fzf: neither sk nor fzf is executable', vim.log.levels.ERROR)
		return
	end

	local command = {
		executable,
		'--ansi',
		'--prompt=❯ ',
		'--reverse',
	}
	local input = table.concat(lines, '\n') .. '\n'

	local job_id = fn.jobstart(command, {
		stdout_buffered = true,
		on_stdout = function(_, data, _)
			if data == nil then
				return
			end

			local selection = data[1]
			if selection == nil or selection == '' then
				return
			end

			sink(selection)
		end,
	})

	if job_id <= 0 then
		vim.notify(string.format('fzf: failed to start %s', executable), vim.log.levels.ERROR)
		return
	end

	fn.chansend(job_id, input)
	fn.chanclose(job_id, 'stdin')
end

M.fzf_pick = fzf_pick

---@return string[]
local function project_files()
	if fn.executable('fd') == 1 then
		return fn.systemlist({
			'fd',
			'--type',
			'f',
			'--strip-cwd-prefix',
		})
	end

	return fn.systemlist({
		'find',
		'.',
		'-type',
		'f',
	})
end

function M.files()
	fzf_pick(project_files(), function(line)
		if line == '' then
			return
		end

		vim.cmd.edit(fn.fnameescape(line))
	end)
end

function M.buffers()
	local buffers = api.nvim_list_bufs()
	local lines = {}

	for _, bufnr in ipairs(buffers) do
		if api.nvim_buf_is_loaded(bufnr) and fn.buflisted(bufnr) == 1 then
			local name = api.nvim_buf_get_name(bufnr)
			if name == '' then
				name = '[No Name]'
			end

			table.insert(lines, string.format('%d %s', bufnr, name))
		end
	end

	fzf_pick(lines, function(line)
		local bufnr = tonumber(line:match('^(%d+)'))
		if bufnr == nil then
			return
		end

		---@cast bufnr integer
		if api.nvim_buf_is_valid(bufnr) then
			api.nvim_set_current_buf(bufnr)
		end
	end)
end

function M.document_symbols()
	local bufnr = api.nvim_get_current_buf()
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
	}

	vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result, ctx, _)
		if err then
			vim.notify('LSP document symbols failed: ' .. (err.message or tostring(err)), vim.log.levels.ERROR)
			return
		end

		if result == nil or vim.tbl_isempty(result) then
			vim.notify('LSP: no symbols', vim.log.levels.WARN)
			return
		end

		local client = vim.lsp.get_client_by_id(ctx.client_id)
		if client == nil then
			vim.notify('LSP client is no longer available', vim.log.levels.WARN)
			return
		end

		local items = vim.lsp.util.symbols_to_items(result, ctx.bufnr, client.offset_encoding)
		local lines = {}

		for _, item in ipairs(items) do
			local lnum = item.lnum or 1
			local text = item.text or ''
			local filename = item.filename

			if filename == nil or filename == '' then
				filename = api.nvim_buf_get_name(ctx.bufnr)
			end
			if filename == '' then
				filename = '[Current]'
			end

			table.insert(lines, string.format('%s:%d:%s', filename, lnum, text))
		end

		fzf_pick(lines, function(line)
			local filename, line_number = line:match('^(.-):(%d+):')

			if filename == nil or line_number == nil then
				return
			end

			if filename ~= '[Current]' then
				vim.cmd.edit(fn.fnameescape(filename))
			end

			local row = tonumber(line_number)
			if row == nil then
				return
			end

			---@cast row integer
			api.nvim_win_set_cursor(0, {
				row,
				0,
			})
		end)
	end)
end
vim.opt.incsearch = true
vim.opt.hlsearch = true
function M.smart_hlsearch()
	local pattern = fn.getreg('/')
	local enabled = pattern ~= nil and pattern ~= ''
	local expected = enabled and 1 or 0

	if vim.v.hlsearch ~= expected then
		vim.opt.hlsearch = enabled
	end
end

function M.highlight_word_under_cursor()
	local word = fn.expand('<cword>')
	if word == nil or word == '' then
		return
	end

	vim.cmd('keepjumps normal! m`')
	fn.setreg('/', '\\V' .. fn.escape(word, '\\'))
	M.smart_hlsearch()
end

function M.next_match()
	vim.cmd('keepjumps normal! n')
	M.smart_hlsearch()
end

function M.prev_match()
	vim.cmd('keepjumps normal! N')
	M.smart_hlsearch()
end

---@param command string
function M.substitute(command)
	local cursor = api.nvim_win_get_cursor(0)
	local old_search = fn.getreg('/')

	vim.cmd('keepjumps ' .. command)
	api.nvim_win_set_cursor(0, cursor)
	fn.setreg('/', old_search)
	M.smart_hlsearch()
end

function M.setup_mappings()
	local map = vim.keymap.set
	local opts = {
		noremap = true,
		silent = true,
	}
	map('n', '*', M.highlight_word_under_cursor, opts)
	map('n', 'n', M.next_match, opts)
	map('n', 'N', M.prev_match, opts)
	map('n', '<leader>h', function()
		if vim.v.hlsearch == 1 then
			vim.opt.hlsearch = false
		else
			M.smart_hlsearch()
		end
	end, opts)
end

local group = api.nvim_create_augroup('SmartSearchSetup', {
	clear = true,
})

api.nvim_create_autocmd('VimEnter', {
	group = group,
	callback = M.setup_mappings,
})

return M
