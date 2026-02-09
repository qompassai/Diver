-- /qompassai/Diver/lua/config/ui/colors.lua
-- Qompass AI Diver Colors Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local api = vim.api
local set_hl = api.nvim_set_hl
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup
local colors = {
    comment = '#7f9bb3',
    comment_doc = '#a0c4ff',
    error = '#ff5f5f',
    hint = '#5fd7af',
    info = '#5fafff',
    warn = '#ffaf00',
    ok = '#5fd75f',
}
function M.setup_colorizer(opts)
    opts = opts or {}
    local ok, colorizer = pcall(require, 'colorizer')
    if not ok then
        return
    end
    local group = augroup('CSS', { clear = false })
    local default_opts = {
        filetypes = {
            'astro',
            'css',
            'html',
            'javascript',
            'jsx',
            'less',
            'lua',
            'markdown',
            'php',
            'sass',
            'scss',
            'stylus',
            'svelte',
            'tsx',
            'typescript',
            'vim',
            'vue',
        },
        user_default_options = {
            css = true,
            css_fn = true,
            RGB = true,
            RRGGBB = true,
            names = true,
            RRGGBBAA = true,
            AARRGGBB = true,
            rgb_fn = true,
            hsl_fn = true,
            mode = 'background',
            tailwind = true,
            sass = { enable = true, parsers = { 'css' } },
            virtualtext = '■',
            always_update = true,
        },
        buftypes = {},
    }
    local merged = vim.tbl_deep_extend('force', default_opts, opts)
    colorizer.setup(merged)
    autocmd('FileType', {
        group = group,
        pattern = merged.filetypes,
        callback = function()
            colorizer.attach_to_buffer(0)
        end,
    })
end

function M.setup_highlights()
    vim.schedule(function()
        local function diag_hl(type, fg, bg)
            local prefix = 'Diagnostic'
            set_hl(0, prefix .. type, { fg = fg })
            set_hl(0, prefix .. 'VirtualText' .. type, { fg = fg, bg = bg })
            set_hl(0, prefix .. 'Underline' .. type, { undercurl = true, sp = fg })
            set_hl(0, prefix .. 'Sign' .. type, { fg = fg })
            set_hl(0, prefix .. 'Floating' .. type, { fg = fg })
        end
        diag_hl('Error', colors.error, '#3b1f1f')
        diag_hl('Warn', colors.warn, '#3b2f1f')
        diag_hl('Info', colors.info, '#1f2f3b')
        diag_hl('Hint', colors.hint, '#1f3b2f')
        diag_hl('Ok', colors.ok, '#1f3b1f')
        local function set_hls(groups)
            for name, opts in pairs(groups) do
                set_hl(0, name, opts)
            end
        end
        set_hls({
            ['@attribute'] = { fg = '#7aa2f7' },
            ['@boolean'] = { fg = '#ff9e64', bold = false },
            ['@character'] = { fg = '#7dcfff' },
            ['@character.special'] = { fg = '#e0af68' },
            ['@conditional'] = { fg = '#bb9af7', bold = false },
            ['@constant'] = { fg = '#ff9e64' },
            ['@constant.builtin'] = { fg = '#ff9e64', bold = false },
            ['@constant.macro'] = { fg = '#ff9e64', bold = false },
            ['@constructor'] = { fg = '#7aa2f7', bold = false },
            ['@error'] = { fg = '#db4b4b' },
            ['@exception'] = { fg = '#bb9af7', bold = false },
            ['@field'] = { fg = '#7dcfff' },
            ['@float'] = { fg = '#ff9e64' },
            ['@function'] = { fg = '#7aa2f7', bold = false },
            ['@function.builtin'] = { fg = '#61AFEF', bold = false },
            ['@function.call'] = { fg = '#7aa2f7' },
            ['@function.macro'] = { fg = '#7aa2f7', bold = false },
            ['@include'] = { fg = '#bb9af7', bold = false },
            ['@keyword'] = { fg = '#bb9af7', bold = false },
            ['@keyword.function'] = { fg = '#bb9af7', bold = false },
            ['@keyword.operator'] = { fg = '#bb9af7' },
            ['@keyword.return'] = { fg = '#bb9af7', bold = false },
            ['@label'] = { fg = '#7aa2f7' },
            ['@method'] = { fg = '#7aa2f7', bold = false },
            ['@method.call'] = { fg = '#7aa2f7' },
            ['@namespace'] = { fg = '#7dcfff' },
            ['@number'] = { fg = '#ff9e64' },
            ['@operator'] = { fg = '#89ddff' },
            ['@parameter'] = { fg = '#e0af68', italic = true },
            ['@parameter.reference'] = { fg = '#e0af68' },
            ['@property'] = { fg = '#7dcfff' },
            ['@punctuation.bracket'] = { fg = '#a4bac1' },
            ['@punctuation.delimiter'] = { fg = '#89ddff' },
            ['@punctuation.special'] = { fg = '#89ddff' },
            ['@repeat'] = { fg = '#bb9af7', bold = false },
            ['@string'] = { fg = '#89dceb' },
            ['@string.escape'] = { fg = '#bb9af7' },
            ['@string.regex'] = { fg = '#bb9af7' },
            ['@string.special'] = { fg = '#e0af68' },
            ['@symbol'] = { fg = '#7dcfff' },
            ['@tag'] = { fg = '#f7768e' },
            ['@tag.attribute'] = { fg = '#7dcfff' },
            ['@tag.delimiter'] = { fg = '#89ddff' },
            ['@text'] = { fg = '#c0caf5' },
            ['@text.danger'] = { fg = '#db4b4b', bold = false },
            ['@text.emphasis'] = { italic = true },
            ['@text.literal'] = { fg = '#9ece6a' },
            ['@text.note'] = { fg = '#0db9d7', bold = false },
            ['@text.reference'] = { fg = '#7dcfff', underline = true },
            ['@text.strong'] = { bold = true },
            ['@text.title'] = { fg = '#7aa2f7', bold = true },
            ['@text.underline'] = { underline = true },
            ['@text.uri'] = { fg = '#7dcfff', underline = true },
            ['@text.warning'] = { fg = '#e0af68', bold = false },
            ['@type'] = { fg = '#7aa2f7', bold = true },
            ['@type.builtin'] = { fg = '#61AFEF', bold = false },
            ['@type.definition'] = { fg = '#7aa2f7', bold = false },
            ['@variable'] = { fg = '#c0caf5' },
            ['@variable.builtin'] = { fg = '#f7768e', bold = false },
            Comment = { fg = colors.comment, italic = true },
            ['@comment'] = { fg = colors.comment, italic = true },
            ['@comment.documentation'] = { italic = true, fg = colors.comment_doc },
            CursorColumn = { bg = '#262a32' },
            CursorLine = { bg = 'none', underline = false },
            CurSearch = { bg = '#EFBD5D', fg = '#000000' },
            DiffAdd = { fg = '#00ff87', bg = 'none', bold = false },
            DiffChange = { fg = colors.warn, bg = 'none' },
            DiffDelete = { fg = colors.error, bg = 'none', bold = false },
            DiffText = { fg = '#00bfff', bg = 'none', bold = true },
            DiagnosticUnderlineError = {
                undercurl = true,
                sp = '#db4b4b',
            },
            EndOfBuffer = { bg = 'none' },
            FloatBorder = { bg = 'none' },
            FoldColumn = { bg = 'none' },
            Folded = { bg = 'none' },
            IncSearch = { bg = '#F15664', fg = '#000000' },
            Search = { bg = '#8BCD5B', fg = '#202020' },
            IlluminatedWordText = { bg = '#2d3139', underline = false },
            IlluminatedWordRead = { bg = '#2d3139', underline = false },
            IlluminatedWordWrite = { bg = '#3d3139', underline = false },
            IndentBlanklineChar = { fg = '#4DA6FF', nocombine = true },
            IndentLevel1 = { fg = '#E06C75' },
            IndentLevel2 = { fg = '#E5C07B' },
            IndentLevel3 = { fg = '#61AFEF' },
            IndentLevel4 = { fg = '#D19A66' },
            IndentLevel5 = { fg = '#98C379' },
            IndentLevel6 = { fg = '#C678DD' },
            IndentLevel7 = { fg = '#56B6C2' },
            ['@keyword.import'] = { link = '@keyword', bold = false },
            ['@lsp.mod.deprecated'] = {
                strikethrough = true,
            },
            LspSemantic_parameter = { fg = '#89b4fa', italic = true },
            LspSemantic_property = { fg = '#fab387' },
            LspSemantic_variable_mutable = { fg = '#f38ba8' },
            ['@lsp.type.class.lua'] = {
                fg = '#f7768e',
                bold = false,
                italic = true,
                underline = true,
            },
            ['@lsp.type.boolean'] = { link = '@boolean' },
            ['@lsp.type.builtinType'] = { link = '@type.builtin' },
            ['@lsp.type.comment'] = { link = '@comment' },
            ['@lsp.type.enum'] = { link = '@type' },
            ['@lsp.type.enumMember'] = { link = '@constant' },
            ['@lsp.type.escapeSequence'] = { link = '@string.escape' },
            ['@lsp.type.formatSpecifier'] = { link = '@punctuation.special' },
            ['@lsp.type.interface'] = { fg = '#7aa2f7' },
            ['@lsp.type.keyword'] = { link = '@keyword' },
            ['@lsp.type.namespace'] = { link = '@namespace' },
            ['@lsp.type.number'] = { link = '@number' },
            ['@lsp.type.operator'] = { link = '@operator' },
            ['@lsp.type.parameter'] = { link = '@parameter' },
            ['@lsp.type.property'] = { link = '@property' },
            ['@lsp.type.selfKeyword'] = { link = '@variable.builtin' },
            ['@lsp.type.typeAlias'] = { link = '@type.definition' },
            ['@lsp.type.unresolvedReference'] = { undercurl = true, sp = '#db4b4b' },
            ['@lsp.type.variable'] = {}, -- Use treesitter for regular variables
            ['@lsp.typemod.class.defaultLibrary'] = { link = '@type.builtin' },
            ['@lsp.typemod.enum.defaultLibrary'] = { link = '@type.builtin' },
            ['@lsp.typemod.enumMember.defaultLibrary'] = { link = '@constant.builtin' },
            ['@lsp.typemod.function.defaultLibrary'] = { link = '@function.builtin' },
            ['@lsp.typemod.keyword.async'] = { link = '@keyword' },
            ['@lsp.typemod.macro.defaultLibrary'] = { link = '@function.builtin' },
            ['@lsp.typemod.method.defaultLibrary'] = { link = '@function.builtin' },
            ['@lsp.typemod.operator.injected'] = { link = '@operator' },
            ['@lsp.typemod.string.injected'] = { link = '@string' },
            ['@lsp.typemod.type.defaultLibrary'] = { fg = '#61AFEF', bold = false },
            ['@lsp.typemod.variable.defaultLibrary'] = { link = '@variable.builtin' },
            ['@lsp.typemod.variable.injected'] = { link = '@variable' },
            ['@lsp.type.function.lua'] = { fg = '#E5C07B', bold = false },
            ['@lsp.type.parameter.lua'] = { fg = '#e0af68', bold = false },
            ['@lsp.type.property.lua'] = { fg = '#7aa2f7', bold = true },
            ['@lsp.type.variable.lua'] = { fg = '#7df9ff', bold = true },
            markdownCode = { italic = true },
            markdownCodeBlock = { italic = false },
            markdownCodeDelimiter = { italic = false },
            ModeMsg = { fg = '#c0caf5', bold = false },
            MoreMsg = { fg = '#0db9d7' },

            Normal = { bg = 'none' },
            NormalFloat = {
                bg = '#1a1b26',
                blend = 50,
            },
            Pmenu = { fg = '#c0caf5', bg = '#1f2335' },
            PmenuSel = { fg = '#000000', bg = '#7aa2f7', bold = true },
            PmenuSbar = { bg = '#292e42' },
            PmenuThumb = { bg = '#565f89' },
            PmenuKind = { fg = '#e0af68', bg = '#1f2335' },
            PmenuKindSel = { fg = '#000000', bg = '#7aa2f7' },
            PmenuExtra = { fg = '#565f89', bg = '#1f2335' },
            PmenuExtraSel = { fg = '#000000', bg = '#7aa2f7' },

            StatusLine = { fg = '#c0caf5', bg = '#1f2335' },
            StatusLineNC = { fg = '#565f89', bg = '#16161e' },
            TabLine = { fg = '#565f89', bg = '#16161e' },
            TabLineFill = { bg = '#16161e' },
            TabLineSel = { fg = '#c0caf5', bg = '#1f2335', bold = false },
            WinBar = { fg = '#c0caf5', bg = 'none' },
            WinBarNC = { fg = '#565f89', bg = 'none' },
            WinSeparator = { fg = '#3b4261', bg = 'none' },
            SignColumn = { bg = 'none' },
            SpellBad = { undercurl = true, sp = '#db4b4b' },
            SpellCap = { undercurl = true, sp = '#e0af68' },
            SpellLocal = { undercurl = true, sp = '#0db9d7' },
            SpellRare = { undercurl = true, sp = '#1abc9c' },
            Terminal = { bg = 'none' },

            Pmenu = { bg = 'none' },
            NvimTreeEndOfBuffer = { bg = 'none' },
            NvimTreeNormal = { bg = 'none' },
            NvimTreeVertSplit = { bg = 'none' },
            ['@punctuation.bracket'] = { fg = '#a4bac1' },
            Visual = { bg = '#103070' },
        })
    end)
    autocmd('BufEnter', {
        once = true,
        callback = function()
            set_hl(0, 'Comment', { fg = colors.comment, italic = true })
            set_hl(0, '@comment', { fg = colors.comment, italic = true })
            set_hl(0, '@comment.documentation', { italic = true, fg = colors.comment_doc })
        end,
    })
end

function M.setup(opts)
    opts = opts or {}
    M.setup_highlights()
    if opts.colorizer ~= false then
        M.setup_colorizer(opts.colorizer)
    end
end

M.setup()
return M
