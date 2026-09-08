-- /qompassai/Diver/lua/config/ui/colors.lua
-- Qompass AI Diver UI Colors Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}

local api = vim.api

local palette = {
	background = '#1a1b26',
	background_alt = '#1f2335',
	background_dark = '#16161e',
	background_soft = '#292e42',
	black = '#000000',
	blue = '#7aa2f7',
	blue_bright = '#5fafff',
	blue_dark = '#103070',
	comment = '#7f9bb3',
	comment_documentation = '#a0c4ff',
	cyan = '#7dcfff',
	cyan_bright = '#7df9ff',
	error = '#ff5f5f',
	error_dark = '#db4b4b',
	foreground = '#c0caf5',
	green = '#9ece6a',
	green_bright = '#00ff87',
	hint = '#5fd7af',
	info = '#5fafff',
	magenta = '#bb9af7',
	muted = '#565f89',
	ok = '#5fd75f',
	orange = '#ff9e64',
	red = '#f7768e',
	selection = '#103070',
	separator = '#3b4261',
	teal = '#0db9d7',
	white = '#ffffff',
	yellow = '#e0af68',
	warn = '#ffaf00',
}

---@param groups table<string, vim.api.keyset.highlight>
local function set_highlights(groups)
	for name, spec in pairs(groups) do
		api.nvim_set_hl(0, name, spec)
	end
end

---@param severity string
---@param foreground string
---@param background string
local function set_diagnostic_highlights(severity, foreground, background)
	local prefix = 'Diagnostic'

	api.nvim_set_hl(0, prefix .. severity, {
		fg = foreground,
	})
	api.nvim_set_hl(0, prefix .. 'VirtualText' .. severity, {
		bg = background,
		fg = foreground,
	})
	api.nvim_set_hl(0, prefix .. 'Underline' .. severity, {
		sp = foreground,
		undercurl = true,
	})
	api.nvim_set_hl(0, prefix .. 'Sign' .. severity, {
		fg = foreground,
	})
	api.nvim_set_hl(0, prefix .. 'Floating' .. severity, {
		fg = foreground,
	})
end

local function apply_diagnostic_highlights()
	set_diagnostic_highlights('Error', palette.error, '#3b1f1f')
	set_diagnostic_highlights('Warn', palette.warn, '#3b2f1f')
	set_diagnostic_highlights('Info', palette.info, '#1f2f3b')
	set_diagnostic_highlights('Hint', palette.hint, '#1f3b2f')
	set_diagnostic_highlights('Ok', palette.ok, '#1f3b1f')

	set_highlights({
		DiagnosticDeprecated = {
			sp = palette.warn,
			strikethrough = true,
		},
		DiagnosticUnnecessary = {
			fg = palette.muted,
		},
	})
end
local function apply_editor_highlights()
	set_highlights({
		ColorColumn = {
			bg = palette.background_alt,
		},
		CurSearch = {
			bg = '#efbd5d',
			fg = palette.black,
		},
		CursorColumn = {
			bg = '#262a32',
		},
		CursorLine = {
			bg = '#20232b',
		},
		CursorLineNr = {
			bold = true,
			fg = palette.blue,
		},
		Directory = {
			fg = palette.blue,
		},
		EndOfBuffer = {
			bg = 'NONE',
			fg = palette.background_dark,
		},
		ErrorMsg = {
			bold = true,
			fg = palette.error,
		},
		FloatBorder = {
			bg = palette.background,
			fg = palette.separator,
		},
		FloatFooter = {
			bg = palette.background,
			fg = palette.muted,
		},
		FloatTitle = {
			bg = palette.background,
			bold = true,
			fg = palette.blue,
		},
		FoldColumn = {
			bg = 'NONE',
			fg = palette.muted,
		},
		Folded = {
			bg = palette.background_alt,
			fg = palette.comment,
		},
		IncSearch = {
			bg = '#f15664',
			fg = palette.black,
		},
		LineNr = {
			fg = palette.muted,
		},
		LineNrAbove = {
			fg = palette.muted,
		},
		LineNrBelow = {
			fg = palette.muted,
		},
		MatchParen = {
			bold = true,
			fg = palette.yellow,
			underline = true,
		},
		ModeMsg = {
			bold = false,
			fg = palette.foreground,
		},
		MoreMsg = {
			fg = palette.teal,
		},
		MsgArea = {
			fg = palette.foreground,
		},
		NonText = {
			fg = palette.muted,
		},
		Normal = {
			bg = 'NONE',
			fg = palette.foreground,
		},
		NormalFloat = {
			bg = palette.background,
			fg = palette.foreground,
		},
		NormalNC = {
			bg = 'NONE',
			fg = palette.foreground,
		},
		Pmenu = {
			bg = palette.background_alt,
			fg = palette.foreground,
		},
		PmenuExtra = {
			bg = palette.background_alt,
			fg = palette.muted,
		},
		PmenuExtraSel = {
			bg = palette.blue,
			fg = palette.black,
		},
		PmenuKind = {
			bg = palette.background_alt,
			fg = palette.yellow,
		},
		PmenuKindSel = {
			bg = palette.blue,
			fg = palette.black,
		},
		PmenuMatch = {
			bg = palette.background_alt,
			bold = true,
			fg = palette.cyan,
		},
		PmenuMatchSel = {
			bg = palette.blue,
			bold = true,
			fg = palette.black,
		},
		PmenuSbar = {
			bg = palette.background_soft,
		},
		PmenuSel = {
			bg = palette.blue,
			bold = true,
			fg = palette.black,
		},
		PmenuThumb = {
			bg = palette.muted,
		},
		Question = {
			fg = palette.cyan,
		},
		QuickFixLine = {
			bg = palette.background_alt,
			bold = true,
		},
		Search = {
			bg = '#8bcd5b',
			fg = '#202020',
		},
		SignColumn = {
			bg = 'NONE',
			fg = palette.muted,
		},
		SpecialKey = {
			fg = palette.muted,
		},
		StatusLine = {
			bg = palette.background_alt,
			fg = palette.foreground,
		},
		StatusLineNC = {
			bg = palette.background_dark,
			fg = palette.muted,
		},
		Substitute = {
			bg = palette.red,
			fg = palette.black,
		},
		TabLine = {
			bg = palette.background_dark,
			fg = palette.muted,
		},
		TabLineFill = {
			bg = palette.background_dark,
		},
		TabLineSel = {
			bg = palette.background_alt,
			bold = true,
			fg = palette.foreground,
		},
		Title = {
			bold = true,
			fg = palette.blue,
		},
		Visual = {
			bg = palette.selection,
		},
		WarningMsg = {
			fg = palette.warn,
		},
		Whitespace = {
			fg = palette.muted,
		},
		WildMenu = {
			bg = palette.blue,
			fg = palette.black,
		},
		WinBar = {
			bg = 'NONE',
			fg = palette.foreground,
		},
		WinBarNC = {
			bg = 'NONE',
			fg = palette.muted,
		},
		WinSeparator = {
			bg = 'NONE',
			fg = palette.separator,
		},
	})
end

local function apply_syntax_highlights()
	set_highlights({
		Boolean = {
			fg = palette.orange,
		},
		Character = {
			fg = palette.cyan,
		},
		Comment = {
			fg = palette.comment,
			italic = true,
		},
		Conditional = {
			fg = palette.magenta,
		},
		Constant = {
			fg = palette.orange,
		},
		Debug = {
			fg = palette.red,
		},
		Define = {
			fg = palette.magenta,
		},
		Delimiter = {
			fg = '#89ddff',
		},
		Error = {
			fg = palette.error_dark,
		},
		Exception = {
			fg = palette.magenta,
		},
		Float = {
			fg = palette.orange,
		},
		Function = {
			fg = palette.blue,
		},
		Identifier = {
			fg = palette.foreground,
		},
		Ignore = {
			fg = palette.muted,
		},
		Include = {
			fg = palette.magenta,
		},
		Keyword = {
			fg = palette.magenta,
		},
		Label = {
			fg = palette.blue,
		},
		Macro = {
			fg = palette.blue,
		},
		Number = {
			fg = palette.orange,
		},
		Operator = {
			fg = '#89ddff',
		},
		PreCondit = {
			fg = palette.magenta,
		},
		PreProc = {
			fg = palette.magenta,
		},
		Repeat = {
			fg = palette.magenta,
		},
		Special = {
			fg = palette.yellow,
		},
		SpecialChar = {
			fg = palette.yellow,
		},
		SpecialComment = {
			fg = palette.comment_documentation,
			italic = true,
		},
		Statement = {
			fg = palette.magenta,
		},
		StorageClass = {
			fg = palette.blue,
		},
		String = {
			fg = '#89dceb',
		},
		Structure = {
			fg = palette.blue,
		},
		Tag = {
			fg = palette.red,
		},
		Todo = {
			bold = true,
			fg = palette.warn,
		},
		Type = {
			bold = true,
			fg = palette.blue,
		},
		Typedef = {
			fg = palette.blue,
		},
		Underlined = {
			underline = true,
		},
	})
end

local function apply_diff_and_spell_highlights()
	set_highlights({
		DiffAdd = {
			bg = 'NONE',
			fg = palette.green_bright,
		},
		DiffChange = {
			bg = 'NONE',
			fg = palette.warn,
		},
		DiffDelete = {
			bg = 'NONE',
			fg = palette.error,
		},
		DiffText = {
			bg = 'NONE',
			bold = true,
			fg = '#00bfff',
		},
		SpellBad = {
			sp = palette.error_dark,
			undercurl = true,
		},
		SpellCap = {
			sp = palette.yellow,
			undercurl = true,
		},
		SpellLocal = {
			sp = palette.teal,
			undercurl = true,
		},
		SpellRare = {
			sp = '#1abc9c',
			undercurl = true,
		},
	})
end

local function apply_treesitter_highlights()
	set_highlights({
		['@attribute'] = {
			fg = palette.blue,
		},
		['@attribute.builtin'] = {
			fg = palette.cyan,
		},
		['@boolean'] = {
			fg = palette.orange,
		},
		['@character'] = {
			fg = palette.cyan,
		},
		['@character.special'] = {
			fg = palette.yellow,
		},
		['@comment'] = {
			fg = palette.comment,
			italic = true,
		},
		['@comment.documentation'] = {
			fg = palette.comment_documentation,
			italic = true,
		},
		['@comment.error'] = {
			bold = true,
			fg = palette.error_dark,
		},
		['@comment.note'] = {
			bold = true,
			fg = palette.teal,
		},
		['@comment.todo'] = {
			bold = true,
			fg = palette.blue,
		},
		['@comment.warning'] = {
			bold = true,
			fg = palette.yellow,
		},
		['@constant'] = {
			fg = palette.orange,
		},
		['@constant.builtin'] = {
			fg = palette.orange,
		},
		['@constant.macro'] = {
			fg = palette.orange,
		},
		['@constructor'] = {
			fg = palette.blue,
		},
		['@diff.delta'] = {
			fg = palette.warn,
		},
		['@diff.minus'] = {
			fg = palette.error,
		},
		['@diff.plus'] = {
			fg = palette.green_bright,
		},
		['@function'] = {
			fg = palette.blue,
		},
		['@function.builtin'] = {
			fg = palette.blue_bright,
		},
		['@function.call'] = {
			fg = palette.blue,
		},
		['@function.macro'] = {
			fg = palette.blue,
		},
		['@function.method'] = {
			fg = palette.blue,
		},
		['@function.method.call'] = {
			fg = palette.blue,
		},
		['@keyword'] = {
			fg = palette.magenta,
		},
		['@keyword.conditional'] = {
			fg = palette.magenta,
		},
		['@keyword.conditional.ternary'] = {
			fg = palette.magenta,
		},
		['@keyword.coroutine'] = {
			fg = palette.magenta,
		},
		['@keyword.debug'] = {
			fg = palette.red,
		},
		['@keyword.directive'] = {
			fg = palette.magenta,
		},
		['@keyword.directive.define'] = {
			fg = palette.magenta,
		},
		['@keyword.exception'] = {
			fg = palette.magenta,
		},
		['@keyword.function'] = {
			fg = palette.magenta,
		},
		['@keyword.import'] = {
			fg = palette.magenta,
		},
		['@keyword.modifier'] = {
			fg = palette.magenta,
		},
		['@keyword.operator'] = {
			fg = palette.magenta,
		},
		['@keyword.repeat'] = {
			fg = palette.magenta,
		},
		['@keyword.return'] = {
			fg = palette.magenta,
		},
		['@keyword.type'] = {
			fg = palette.magenta,
		},
		['@label'] = {
			fg = palette.blue,
		},
		['@module'] = {
			fg = palette.cyan,
		},
		['@module.builtin'] = {
			fg = palette.cyan,
		},
		['@number'] = {
			fg = palette.orange,
		},
		['@number.float'] = {
			fg = palette.orange,
		},
		['@operator'] = {
			fg = '#89ddff',
		},
		['@property'] = {
			fg = palette.cyan,
		},
		['@punctuation.bracket'] = {
			fg = '#a4bac1',
		},
		['@punctuation.delimiter'] = {
			fg = '#89ddff',
		},
		['@punctuation.special'] = {
			fg = '#89ddff',
		},
		['@string'] = {
			fg = '#89dceb',
		},
		['@string.documentation'] = {
			fg = palette.comment_documentation,
			italic = true,
		},
		['@string.escape'] = {
			fg = palette.magenta,
		},
		['@string.regexp'] = {
			fg = palette.magenta,
		},
		['@string.special'] = {
			fg = palette.yellow,
		},
		['@string.special.path'] = {
			fg = palette.cyan,
		},
		['@string.special.symbol'] = {
			fg = palette.cyan,
		},
		['@string.special.url'] = {
			fg = palette.cyan,
			underline = true,
		},
		['@tag'] = {
			fg = palette.red,
		},
		['@tag.attribute'] = {
			fg = palette.cyan,
		},
		['@tag.builtin'] = {
			fg = palette.red,
		},
		['@tag.delimiter'] = {
			fg = '#89ddff',
		},
		['@type'] = {
			bold = true,
			fg = palette.blue,
		},
		['@type.builtin'] = {
			fg = palette.blue_bright,
		},
		['@type.definition'] = {
			fg = palette.blue,
		},
		['@variable'] = {
			fg = palette.foreground,
		},
		['@variable.builtin'] = {
			fg = palette.red,
		},
		['@variable.member'] = {
			fg = palette.cyan,
		},
		['@variable.parameter'] = {
			fg = palette.yellow,
			italic = true,
		},
		['@variable.parameter.builtin'] = {
			fg = palette.red,
			italic = true,
		},
	})
end

local function apply_markup_highlights()
	set_highlights({
		['@markup.heading'] = {
			bold = true,
			fg = palette.blue,
		},
		['@markup.heading.1'] = {
			bold = true,
			fg = palette.blue,
		},
		['@markup.heading.2'] = {
			bold = true,
			fg = palette.cyan,
		},
		['@markup.heading.3'] = {
			bold = true,
			fg = palette.green,
		},
		['@markup.heading.4'] = {
			bold = true,
			fg = palette.yellow,
		},
		['@markup.heading.5'] = {
			bold = true,
			fg = palette.orange,
		},
		['@markup.heading.6'] = {
			bold = true,
			fg = palette.magenta,
		},
		['@markup.italic'] = {
			italic = true,
		},
		['@markup.link'] = {
			fg = palette.cyan,
		},
		['@markup.link.label'] = {
			fg = palette.cyan,
		},
		['@markup.link.url'] = {
			fg = palette.cyan,
			underline = true,
		},
		['@markup.list'] = {
			fg = palette.blue,
		},
		['@markup.list.checked'] = {
			fg = palette.ok,
		},
		['@markup.list.unchecked'] = {
			fg = palette.muted,
		},
		['@markup.math'] = {
			fg = palette.yellow,
		},
		['@markup.quote'] = {
			fg = palette.comment,
			italic = true,
		},
		['@markup.raw'] = {
			fg = palette.green,
		},
		['@markup.raw.block'] = {
			fg = palette.green,
		},
		['@markup.strikethrough'] = {
			strikethrough = true,
		},
		['@markup.strong'] = {
			bold = true,
		},
		['@markup.underline'] = {
			underline = true,
		},
	})
end

local function apply_lsp_highlights()
	set_highlights({
		LspCodeLens = {
			fg = palette.muted,
		},
		LspCodeLensSeparator = {
			fg = palette.separator,
		},
		LspInlayHint = {
			bg = palette.background_alt,
			fg = palette.muted,
			italic = true,
		},
		LspReferenceRead = {
			bg = '#2d3139',
		},
		LspReferenceText = {
			bg = '#2d3139',
		},
		LspReferenceWrite = {
			bg = '#3d3139',
		},
		LspSignatureActiveParameter = {
			bold = true,
			fg = palette.yellow,
		},
		['@lsp.mod.deprecated'] = {
			strikethrough = true,
		},
		['@lsp.type.boolean'] = {
			link = '@boolean',
		},
		['@lsp.type.builtinType'] = {
			link = '@type.builtin',
		},
		['@lsp.type.class'] = {
			link = '@type',
		},
		['@lsp.type.class.lua'] = {
			fg = palette.red,
			italic = true,
			underline = true,
		},
		['@lsp.type.comment'] = {
			link = '@comment',
		},
		['@lsp.type.decorator'] = {
			link = '@attribute',
		},
		['@lsp.type.enum'] = {
			link = '@type',
		},
		['@lsp.type.enumMember'] = {
			link = '@constant',
		},
		['@lsp.type.escapeSequence'] = {
			link = '@string.escape',
		},
		['@lsp.type.event'] = {
			link = '@type',
		},
		['@lsp.type.formatSpecifier'] = {
			link = '@punctuation.special',
		},
		['@lsp.type.function'] = {
			link = '@function',
		},
		['@lsp.type.function.lua'] = {
			fg = '#e5c07b',
		},
		['@lsp.type.interface'] = {
			link = '@type',
		},
		['@lsp.type.keyword'] = {
			link = '@keyword',
		},
		['@lsp.type.macro'] = {
			link = '@function.macro',
		},
		['@lsp.type.method'] = {
			link = '@function.method',
		},
		['@lsp.type.modifier'] = {
			link = '@keyword.modifier',
		},
		['@lsp.type.namespace'] = {
			link = '@module',
		},
		['@lsp.type.number'] = {
			link = '@number',
		},
		['@lsp.type.operator'] = {
			link = '@operator',
		},
		['@lsp.type.parameter'] = {
			link = '@variable.parameter',
		},
		['@lsp.type.parameter.lua'] = {
			fg = palette.yellow,
		},
		['@lsp.type.property'] = {
			link = '@property',
		},
		['@lsp.type.property.lua'] = {
			bold = true,
			fg = palette.blue,
		},
		['@lsp.type.regexp'] = {
			link = '@string.regexp',
		},
		['@lsp.type.selfKeyword'] = {
			link = '@variable.builtin',
		},
		['@lsp.type.string'] = {
			link = '@string',
		},
		['@lsp.type.struct'] = {
			link = '@type',
		},
		['@lsp.type.type'] = {
			link = '@type',
		},
		['@lsp.type.typeAlias'] = {
			link = '@type.definition',
		},
		['@lsp.type.typeParameter'] = {
			link = '@type',
		},
		['@lsp.type.unresolvedReference'] = {
			sp = palette.error_dark,
			undercurl = true,
		},
		['@lsp.type.variable'] = {
			link = '@variable',
		},
		['@lsp.type.variable.lua'] = {
			bold = true,
			fg = palette.cyan_bright,
		},
		['@lsp.typemod.class.defaultLibrary'] = {
			link = '@type.builtin',
		},
		['@lsp.typemod.enum.defaultLibrary'] = {
			link = '@type.builtin',
		},
		['@lsp.typemod.enumMember.defaultLibrary'] = {
			link = '@constant.builtin',
		},
		['@lsp.typemod.function.defaultLibrary'] = {
			link = '@function.builtin',
		},
		['@lsp.typemod.keyword.async'] = {
			link = '@keyword.coroutine',
		},
		['@lsp.typemod.macro.defaultLibrary'] = {
			link = '@function.builtin',
		},
		['@lsp.typemod.method.defaultLibrary'] = {
			link = '@function.builtin',
		},
		['@lsp.typemod.operator.injected'] = {
			link = '@operator',
		},
		['@lsp.typemod.string.injected'] = {
			link = '@string',
		},
		['@lsp.typemod.type.defaultLibrary'] = {
			link = '@type.builtin',
		},
		['@lsp.typemod.variable.defaultLibrary'] = {
			link = '@variable.builtin',
		},
		['@lsp.typemod.variable.injected'] = {
			link = '@variable',
		},
	})
end
local function apply_highlights()
	apply_editor_highlights()
	apply_syntax_highlights()
	apply_diff_and_spell_highlights()
	apply_diagnostic_highlights()
	apply_treesitter_highlights()
	apply_markup_highlights()
	apply_lsp_highlights()
end

function M.setup()
	local group = api.nvim_create_augroup('UIColors', {
		clear = true,
	})

	api.nvim_create_autocmd('ColorScheme', {
		callback = apply_highlights,
		desc = 'Reapply UI highlights after colorscheme changes',
		group = group,
	})

	apply_highlights()
end

M.setup()

return M
