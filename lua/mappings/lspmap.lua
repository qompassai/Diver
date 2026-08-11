-- /qompassai/Diver/lua/mappings/lspmap.lua
-- Qompass AI Diver Language Server Protocol (LSP) Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.lspmap'
local M = {}
local api = vim.api
local jump = vim.diagnostic.jump
local notify = vim.notify

---@alias LspAttachArgs { buf: integer, data?: { client_id?: integer } }

---@param bufnr integer
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
---@param extra? table
local function buf_map(bufnr, mode, lhs, rhs, desc, extra)
	local options = {
		buffer = bufnr,
		desc = desc,
		silent = true,
	}
	if extra then
		options = vim.tbl_extend('force', options, extra)
	end
	vim.keymap.set(mode, lhs, rhs, options)
end

---@param clients vim.lsp.Client[]
---@param method string
---@return boolean
local function supports(clients, method)
	for _, client in ipairs(clients) do
		if client:supports_method(method) then
			return true
		end
	end
	return false
end
---@param options table
local function definition_list(options)
	local items = options.items or {}
	if #items == 0 then
		notify('No definitions found', vim.log.levels.INFO, {
			title = 'LSP',
		})
		return
	end
	vim.fn.setqflist({}, ' ', {
		items = items,
		title = options.title or 'LSP definitions',
	})
	vim.cmd('cfirst')
end
---@param command string
local function run_ex_command(command)
	local ok, err = pcall(vim.cmd, command)
	if not ok then
		notify(tostring(err), vim.log.levels.ERROR, {
			title = 'LSP mappings',
		})
	end
end

local function show_lsp_clients()
	local bufnr = api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	if vim.tbl_isempty(clients) then
		notify('No LSP clients are attached to the current buffer', vim.log.levels.INFO, {
			title = 'LSP clients',
		})
		return
	end

	local lines = {
		('Buffer %d LSP clients:'):format(bufnr),
	}
	for _, client in ipairs(clients) do
		local root = client.config and client.config.root_dir or client.root_dir or 'n/a'
		lines[#lines + 1] = ('- %s (id=%d, root=%s)'):format(client.name or 'unknown', client.id or -1, tostring(root))
	end
	notify(table.concat(lines, '\n'), vim.log.levels.INFO, {
		title = 'LSP clients',
	})
end

---@param bufnr integer
local function setup_typescript_maps(bufnr)
	buf_map(bufnr, 'n', '<leader>cti', function()
		run_ex_command('TypescriptOrganizeImports')
	end, 'TypeScript: organize imports')
	buf_map(bufnr, 'n', '<leader>ctd', function()
		run_ex_command('TypescriptGoToSourceDefinition')
	end, 'TypeScript: go to source definition')
	buf_map(bufnr, 'n', '<leader>ctm', function()
		run_ex_command('TypescriptAddMissingImports')
	end, 'TypeScript: add missing imports')
end

---@param args LspAttachArgs
function M.on_attach(args)
	local bufnr = args.buf
	local client_id = args.data and args.data.client_id or nil
	if client_id and not vim.lsp.get_client_by_id(client_id) then
		return
	end
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	if vim.tbl_isempty(clients) then
		return
	end
	if supports(clients, 'textDocument/codeAction') then
		buf_map(bufnr, { 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, 'LSP: code action')
	end
	if supports(clients, 'textDocument/definition') then
		buf_map(bufnr, 'n', 'gd', function()
			vim.lsp.buf.definition({ on_list = definition_list })
		end, 'LSP: go to definition')
	end
	if type(vim.lsp.buf.document_color) == 'function' and supports(clients, 'textDocument/documentColor') then
		buf_map(bufnr, 'n', '<leader>lc', vim.lsp.buf.document_color, 'LSP: document colors')
	end
	if supports(clients, 'textDocument/documentSymbol') then
		buf_map(bufnr, 'n', 'gO', vim.lsp.buf.document_symbol, 'LSP: document symbols')
	end
	if supports(clients, 'textDocument/formatting') or supports(clients, 'textDocument/rangeFormatting') then
		buf_map(
			bufnr,
			{
				'n',
				'x',
			},
			'<leader>lf',
			function()
				vim.lsp.buf.format({
					async = true,
					bufnr = bufnr,
				})
			end,
			'LSP: format buffer or selection'
		)
	end
	if supports(clients, 'textDocument/hover') then
		buf_map(bufnr, 'n', 'K', vim.lsp.buf.hover, 'LSP: hover information')
	end
	if supports(clients, 'textDocument/implementation') then
		buf_map(bufnr, 'n', 'gI', vim.lsp.buf.implementation, 'LSP: go to implementation')
	end
	if supports(clients, 'textDocument/rename') then
		buf_map(bufnr, 'n', '<leader>rn', vim.lsp.buf.rename, 'LSP: rename symbol')
	end
	if supports(clients, 'workspace/symbol') then
		buf_map(bufnr, 'n', '<leader>ws', vim.lsp.buf.workspace_symbol, 'LSP: workspace symbols')
	end
	buf_map(bufnr, 'n', '[d', function()
		jump({
			count = -1,
		})
	end, 'Diagnostics: previous')
	buf_map(bufnr, 'n', ']d', function()
		jump({
			count = 1,
		})
	end, 'Diagnostics: next')
	buf_map(bufnr, 'n', '<leader>ld', function()
		vim.diagnostic.open_float(nil, {
			scope = 'line',
		})
	end, 'Diagnostics: show current line')
	buf_map(bufnr, 'n', '<leader>li', show_lsp_clients, 'LSP: show attached clients')

	buf_map(bufnr, 'n', '<leader>lwa', vim.lsp.buf.add_workspace_folder, 'LSP: add workspace folder')
	buf_map(bufnr, 'n', '<leader>lwr', vim.lsp.buf.remove_workspace_folder, 'LSP: remove workspace folder')
	buf_map(bufnr, 'n', '<leader>lwl', function()
		notify(vim.inspect(vim.lsp.buf.list_workspace_folders()), vim.log.levels.INFO, {
			title = 'LSP workspace folders',
		})
	end, 'LSP: list workspace folders')

	if supports(clients, 'textDocument/signatureHelp') then
		buf_map(bufnr, 'i', '<C-k>', vim.lsp.buf.signature_help, 'LSP: signature help')
	end
	buf_map(
		bufnr,
		'i',
		'<C-Space>',
		function()
			if vim.lsp.completion and type(vim.lsp.completion.get) == 'function' then
				vim.lsp.completion.get()
				return ''
			end
			return api.nvim_replace_termcodes('<C-x><C-o>', true, false, true)
		end,
		'LSP: trigger completion',
		{
			expr = true,
		}
	)
	local filetype = vim.bo[bufnr].filetype
	if filetype == 'typescript' or filetype == 'typescriptreact' then
		setup_typescript_maps(bufnr)
	end
end

function M.setup_lspmap()
	if M.configured then
		return
	end
	M.configured = true

	api.nvim_create_user_command('LspClients', show_lsp_clients, {
		desc = 'Show LSP clients attached to the current buffer',
		force = true,
	})
	local group = api.nvim_create_augroup('LspMappings', {
		clear = true,
	})
	api.nvim_create_autocmd('LspAttach', {
		group = group,
		callback = M.on_attach,
	})
end
return M
