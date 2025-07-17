-- marksman.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

local bin_name = 'marksman'
local cmd = { bin_name, 'server' }

return {
	cmd = cmd,
	filetypes = { 'markdown', 'markdown.mdx' },
	root_markers = { '.marksman.toml', '.git' },
}
