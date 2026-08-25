-- /qompassai/Diver/lua/plugins/data.lua
-- Qompass AI Diver Data Plugins
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local function gh(repo)
	return 'https://github.com/' .. repo
end
vim.g.sqlite_clib_path = '/usr/lib/libsqlite3.so'

---@type vim.pack.Spec.List
local specs = {
	{
		src = gh('kkharji/sqlite.lua'),
		version = 'master',
	},
	{
		src = gh('akinsho/toggleterm.nvim'),
		version = vim.version.range('2.*'),
		data = {
			event = 'UIEnter',
			config = function()
				require('toggleterm').setup({
					direction = 'float',
					open_mapping = [[<c-\>]],
					size = 20,
				})
			end,
		},
	},
	{
		src = gh('tpope/vim-dadbod'),
		version = 'master',
	},
	{
		src = gh('kristijanhusak/vim-dadbod-completion'),
		version = 'master',
	},
	{
		src = gh('kristijanhusak/vim-dadbod-ui'),
		version = 'master',
		data = {
			config = function()
				vim.g.db_ui_auto_execute_table_helpers = 1
				vim.g.db_ui_auto_format_results = 1
				vim.g.db_ui_show_help = 1
				vim.g.db_ui_use_nerd_fonts = 1
				vim.g.db_ui_win_position = 'right'
				vim.g.db_ui_winwidth = 40
				vim.g.db_ui_connections = {
					zotero = 'sqlite:///' .. vim.fn.expand('$XDG_DATA_HOME/zotero/zotero.sqlite'),
				}
				require('config.data.common').setup_dadbod_connections(
					vim.fs.joinpath(vim.fn.stdpath('config'), 'dbx.lua')
				)
				require('config.data.sqlite').sqlite_ftd()
			end,
		},
	},
}
return specs
