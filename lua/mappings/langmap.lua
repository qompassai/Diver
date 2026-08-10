-- /qompassai/Diver/lua/mappings/langmap.lua
-- Qompass AI Diver Python Lang Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup_langmap()
	local map = vim.keymap.set
	vim.api.nvim_create_autocmd('LspAttach', {
		callback = function(ev)
			local bufnr = ev.buf
			local opts = {
				noremap = true,
				silent = true,
				buffer = bufnr,
			}
			vim.api.nvim_create_autocmd('FileType', {
				pattern = {
					'mojo',
				},
				callback = function(args)
					if vim.bo[args.buf].filetype ~= 'mojo' then
						return
					end
					vim.opt_local.tabstop = 4
					vim.opt_local.shiftwidth = 4
					vim.opt_local.expandtab = true
					map('n', '<leader>mr', ':MojoRun<CR>', {
						buffer = args.buf,
						desc = 'Run Mojo file',
					})
					map('n', '<leader>dmf', ':MojoDebug<CR>', {
						buffer = args.buf,
						desc = 'Debug Mojo file',
					})
				end,
			})
			map(
				'n',
				'<leader>pl',
				function()
					vim.cmd('PythonLint')
				end,
				vim.tbl_extend('force', opts, {
					desc = '[p]ython [l]int',
				})
			)
			map(
				'n',
				'<leader>ptF',
				function()
					vim.cmd('PyTestFile')
				end,
				vim.tbl_extend('force', opts, {
					desc = '🐍 [p]ython [t]est [F]ile',
				})
			)
			map(
				'n',
				'<leader>ptf',
				function()
					vim.cmd('PyTestFunc')
				end,
				vim.tbl_extend('force', opts, {
					desc = '🐍 [p]ython [t]est [f]unction',
				})
			)
			map(
				'n',
				'<leader>ppi',
				function()
					vim.cmd('PoetryInstall')
				end,
				vim.tbl_extend('force', opts, {
					desc = '🐍 [p]ython [p]oetry [i]nstall',
				})
			)
		end,
	})
end
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
function M.rust_edition(edition)
	if M.rust_editions[edition] then
		M.current_edition = edition
		vim.echo('Rust edition set to ' .. edition, vim.log.levels.INFO)
		vim.cmd('LspRestart')
	else
		vim.echo('Invalid Rust edition: ' .. tostring(edition), vim.log.levels.ERROR)
	end
end

function M.rust_set_toolchain(tc)
	if M.rust_toolchains[tc] then
		M.current_toolchain = tc
		vim.echo('Rust toolchain set to ' .. tc, vim.log.levels.INFO)
		vim.cmd('LspRestart')
	else
		vim.echo('Invalid Rust toolchain: ' .. tostring(tc), vim.log.levels.ERROR)
	end
end

return M
