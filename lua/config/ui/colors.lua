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
            -- Comments
            Comment = { fg = colors.comment, italic = true },
            ['@comment'] = { fg = colors.comment, italic = true },
            ['@comment.documentation'] = { italic = true, fg = colors.comment_doc },
            CursorColumn = { bg = '#262a32' },
            CursorLine = { bg = 'none', underline = false },
            CurSearch = { bg = '#EFBD5D', fg = '#000000' },
            IncSearch = { bg = '#F15664', fg = '#000000' },
            Search = { bg = '#8BCD5B', fg = '#202020' },
            DiffAdd = { fg = '#00ff87', bg = 'none', bold = true },
            DiffChange = { fg = colors.warn, bg = 'none' },
            DiffDelete = { fg = colors.error, bg = 'none', bold = true },
            DiffText = { fg = '#00bfff', bg = 'none', bold = true },
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
            ['@keyword.import'] = { link = '@keyword', bold = true },
            ['@lsp.type.class.lua'] = { fg = '#f7768e', bold = true, underline = true },
            ['@lsp.type.function.lua'] = { fg = '#9ece6a', bold = true },
            ['@lsp.type.parameter.lua'] = { fg = '#e0af68', bold = true },
            ['@lsp.type.property.lua'] = { fg = '#7aa2f7', bold = true },
            ['@lsp.type.variable.lua'] = { fg = '#7df9ff', bold = true },
            LspSemantic_parameter = { fg = '#89b4fa', italic = true },
            LspSemantic_property = { fg = '#fab387' },
            LspSemantic_variable_mutable = { fg = '#f38ba8' },
            markdownCode = { italic = true },
            markdownCodeBlock = { italic = false },
            markdownCodeDelimiter = { italic = true },
            Normal = { bg = 'none' },
            NormalFloat = { bg = 'none' },
            EndOfBuffer = { bg = 'none' },
            FloatBorder = { bg = 'none' },
            FoldColumn = { bg = 'none' },
            Folded = { bg = 'none' },
            Terminal = { bg = 'none' },
            SignColumn = { bg = 'none' },
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
