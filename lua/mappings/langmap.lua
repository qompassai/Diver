-- /qompassai/Diver/lua/mappings/langmap.lua
-- Qompass AI Diver Python Lang Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
M.rust_editions = {
	['2021'] = '2021',
	['2024'] = '2024',
}
M.rust_toolchains = {
	beta = 'beta',
	stable = 'stable',
	nightly = 'nightly',
}
M.rust_default_edition = '2024'
M.rust_default_toolchain = 'nightly'
M.current_edition = M.rust_default_edition
M.current_toolchain = M.rust_default_toolchain

---@param bufnr integer
---@param lhs string
---@param rhs string|function
---@param desc string
local function buf_map(bufnr, lhs, rhs, desc)
	vim.keymap.set('n', lhs, rhs, {
		buffer = bufnr,
		desc = desc,
		silent = true,
	})
end
local function restart_lsp()
	if vim.fn.exists(':LspRestart') == 2 then
		vim.cmd('LspRestart')
		return
	end
	vim.notify('Rust setting changed; restart rust-analyzer to apply it', vim.log.levels.WARN, {
		title = 'Rust mappings',
	})
end
---@param edition string
function M.rust_edition(edition)
	if not M.rust_editions[edition] then
		vim.notify(('Invalid Rust edition: %s'):format(tostring(edition)), vim.log.levels.ERROR, {
			title = 'Rust mappings',
		})
		return
	end
	M.current_edition = edition
	vim.notify(('Rust edition set to %s'):format(edition), vim.log.levels.INFO, {
		title = 'Rust mappings',
	})
	restart_lsp()
end
---@param toolchain string
function M.rust_set_toolchain(toolchain)
	if not M.rust_toolchains[toolchain] then
		vim.notify(('Invalid Rust toolchain: %s'):format(tostring(toolchain)), vim.log.levels.ERROR, {
			title = 'Rust mappings',
		})
		return
	end
	M.current_toolchain = toolchain
	vim.notify(('Rust toolchain set to %s'):format(toolchain), vim.log.levels.INFO, {
		title = 'Rust mappings',
	})
	restart_lsp()
end

---@param group integer
local function setup_python_maps(group)
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = 'python',
		callback = function(args)
			local bufnr = args.buf
			buf_map(bufnr, '<leader>pl', '<cmd>PythonLint<cr>', 'Python: lint buffer')
			buf_map(bufnr, '<leader>ptF', '<cmd>PyTestFile<cr>', 'Python: test file')
			buf_map(bufnr, '<leader>ptf', '<cmd>PyTestFunc<cr>', 'Python: test function')
			buf_map(bufnr, '<leader>ppi', '<cmd>PoetryInstall<cr>', 'Python: install Poetry dependencies')
		end,
	})
end

---@param group integer
local function setup_mojo_maps(group)
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = 'mojo',
		callback = function(args)
			local bufnr = args.buf
			vim.bo[bufnr].tabstop = 4
			vim.bo[bufnr].shiftwidth = 4
			vim.bo[bufnr].expandtab = true
			buf_map(bufnr, '<leader>mr', '<cmd>MojoRun<cr>', 'Mojo: run file')
			buf_map(bufnr, '<leader>dmf', '<cmd>MojoDebug<cr>', 'Mojo: debug file')
		end,
	})
end

---@param group integer
local function setup_rust_maps(group)
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = 'rust',
		callback = function(args)
			local bufnr = args.buf
			buf_map(bufnr, '<leader>re', function()
				vim.ui.select(vim.tbl_keys(M.rust_editions), {
					prompt = 'Select Rust edition',
				}, function(choice)
					if choice then
						M.rust_edition(choice)
					end
				end)
			end, 'Rust: select edition')
			buf_map(bufnr, '<leader>rt', function()
				vim.ui.select(vim.tbl_keys(M.rust_toolchains), {
					prompt = 'Select Rust toolchain',
				}, function(choice)
					if choice then
						M.rust_set_toolchain(choice)
					end
				end)
			end, 'Rust: select toolchain')
		end,
	})
end
function M.setup_langmap()
	if M.configured then
		return
	end
	M.configured = true

	local group = api.nvim_create_augroup('LanguageMappings', {
		clear = true,
	})
	setup_python_maps(group)
	setup_mojo_maps(group)
	setup_rust_maps(group)
	api.nvim_create_user_command('RustEdition', function(options)
		M.rust_edition(options.args)
	end, {
		complete = function()
			return vim.tbl_keys(M.rust_editions)
		end,
		force = true,
		nargs = 1,
	})
	api.nvim_create_user_command('RustToolchain', function(options)
		M.rust_set_toolchain(options.args)
	end, {
		complete = function()
			return vim.tbl_keys(M.rust_toolchains)
		end,
		force = true,
		nargs = 1,
	})
end

return M
