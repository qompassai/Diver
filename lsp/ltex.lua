-- /qompassai/Diver/lsp/ltex.lua
-- Qompass AI Ltex LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local language_id_mapping = {
	bib = 'bibtex',
	plaintex = 'tex',
	rnoweb = 'rsweave',
	rst = 'restructuredtext',
	tex = 'latex',
	lualatex = 'markdown',
	text = 'plaintext',
}

local filetypes = {
	'bib',
	'gitcommit',
	'markdown',
	'org',
	'plaintex',
	'rst',
	'rnoweb',
	'tex',
	'lualatex',
	'quarto',
	'rmd',
	'context',
	'html',
	'xhtml',
	'mail',
	'text',
}

local function get_language_id(_, filetype)
	local language_id = language_id_mapping[filetype]
	if language_id then
		return language_id
	else
		return filetype
	end
end
local enabled_ids = {}
do
	local enabled_keys = {}
	for _, ft in ipairs(filetypes) do
		local id = get_language_id({}, ft)
		if not enabled_keys[id] then
			enabled_keys[id] = true
			table.insert(enabled_ids, id)
		end
	end
end

return {
	cmd = { 'ltex-ls' },
	filetypes = filetypes,
	root_markers = { '.git' },
	get_language_id = get_language_id,
	settings = {
		ltex = {
			enabled = enabled_ids,
			language = "en-US",
		},
	},
}
