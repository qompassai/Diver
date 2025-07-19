-- /qompassai/Diver/lua/plugins/edu/lightbulb.lua
-- Qompass AI Diver Autoload Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

local M = {}

require('edu.lightbulb').setup({
	priority = 10,
	hide_in_unfocused_buffer = true,
	link_highlights = true,
	validate_config = "auto",
	action_kinds = nil,
	code_lenses = true,
	sign = {
		enabled = true,
		text = "💡",
		lens_text = "🔎",
		hl = "LightBulbSign",
	},
	virtual_text = {
		enabled = true,
		text = "💡",
		lens_text = "🔎",
		pos = "eol",
		hl = "LightBulbVirtualText",
		hl_mode = "combine",
	},
	float = {
		enabled = true,
		text = "💡",
		lens_text = "🔎",
		hl = "LightBulbFloatWin",
		win_opts = {
			focusable = true,
		},
	},
	status_text = {
		enabled = true,
		text = "💡",
		lens_text = "🔎",
		text_unavailable = "",
	},
	number = {
		enabled = true,
		hl = "LightBulbNumber",
	},
	line = {
		enabled = true,
		hl = "LightBulbLine",
	},
	autocmd = {
		enabled = true,
		updatetime = 200,
		events = { "CursorHold", "CursorHoldI" },
		pattern = { "*" },
	},
	ignore = {
		-- LSP client names to ignore.
		-- Example: {"null-ls", "lua_ls"}
		clients = {},
		-- Example: {"neo-tree", "lua"}
		ft = {},
		actions_without_kind = false,
	},
	---@type (fun(client_name:string, result:lsp.CodeAction|lsp.Command):boolean)|nil
	filter = nil,
})

return M
