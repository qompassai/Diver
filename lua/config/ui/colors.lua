-- /qompassai/Diver/lua/config/ui/colors.lua
-- Qompass AI Diver Colors Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type HlOpts
vim.cmd('colorscheme vague')
vim.schedule(function()
    vim.api.nvim_set_hl(0, 'Comment', {
        fg = '#7f9bb3',
        italic = true,
    })
    vim.api.nvim_set_hl(0, '@comment', {
        fg = '#7f9bb3',
        italic = true,
    })
    vim.api.nvim_set_hl(0, '@comment.documentation', {
        italic = true,
        fg = '#a0c4ff',
    })
    vim.api.nvim_set_hl(0, 'CursorColumn', {
        bg = '#262a32',
    })
    vim.api.nvim_set_hl(0, 'CursorLine', {
        bg = 'none',
        underline = false,
    })
    vim.api.nvim_set_hl(0, 'CurSearch', {
        bg = '#EFBD5D',
        fg = '#000000',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticError', {
        fg = '#ff5f5f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticWarn', {
        fg = '#ffaf00',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticInfo', {
        fg = '#5fafff',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticHint', {
        fg = '#5fd7af',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticOk', {
        fg = '#5fd75f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', {
        fg = '#ff5f5f',
        bg = '#3b1f1f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', {
        fg = '#ffaf00',
        bg = '#3b2f1f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', {
        fg = '#5fafff',
        bg = '#1f2f3b',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', {
        fg = '#5fd7af',
        bg = '#1f3b2f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextOk', { ---fdfd
        fg = '#5fd75f',
        bg = '#1f3b1f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', {
        undercurl = true,
        sp = '#ff5f5f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', {
        undercurl = true,
        sp = '#ffaf00',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', {
        undercurl = true,
        sp = '#5fafff',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', {
        undercurl = true,
        sp = '#5fd7af',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticUnderlineOk', {
        undercurl = true,
        sp = '#5fd75f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticSignError', {
        fg = '#ff5f5f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticSignWarn', {
        fg = '#ffaf00',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticSignInfo', {
        fg = '#5fafff',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticSignHint', {
        fg = '#5fd7af',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticSignOk', {
        fg = '#5fd75f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticFloatingError', {
        fg = '#ff5f5f',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticFloatingWarn', {
        fg = '#ffaf00',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticFloatingInfo', {
        fg = '#5fafff',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticFloatingHint', {
        fg = '#5fd7af',
    })
    vim.api.nvim_set_hl(0, 'DiagnosticFloatingOk', {
        fg = '#5fd75f',
    })
    vim.api.nvim_set_hl(0, 'DiffAdd', {
        fg = '#00ff87',
        bg = 'none',
        bold = true,
    })

    vim.api.nvim_set_hl(0, 'DiffChange', {
        fg = '#ffaf00',
        bg = 'none',
    })

    vim.api.nvim_set_hl(0, 'DiffDelete', {
        fg = '#ff5f5f',
        bg = 'none',
        bold = true,
    })

    vim.api.nvim_set_hl(0, 'DiffText', {
        fg = '#00bfff',
        bg = 'none',
        bold = true,
    })
    vim.api.nvim_set_hl(0, 'EndOfBuffer', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'FloatBorder', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'FoldColumn', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'Folded', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'IlluminatedWordText', {
        bg = '#2d3139',
        underline = false,
    })
    vim.api.nvim_set_hl(0, 'IlluminatedWordRead', {
        bg = '#2d3139',
        underline = false,
    })
    vim.api.nvim_set_hl(0, 'IlluminatedWordWrite', {
        bg = '#3d3139',
        underline = false,
    })
    vim.api.nvim_set_hl(0, 'IncSearch', {
        bg = '#F15664',
        fg = '#000000',
    })
    vim.api.nvim_set_hl(0, 'IndentBlanklineChar', {
        fg = '#4DA6FF',
        nocombine = true,
    })
    vim.api.nvim_set_hl(0, 'IndentLevel1', {
        fg = '#E06C75',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel2', {
        fg = '#E5C07B',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel3', {
        fg = '#61AFEF',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel4', {
        fg = '#D19A66',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel5', {
        fg = '#98C379',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel6', {
        fg = '#C678DD',
    })
    vim.api.nvim_set_hl(0, 'IndentLevel7', {
        fg = '#56B6C2',
    })
    vim.api.nvim_set_hl(0, '@keyword.import', {
        link = '@keyword',
        bold = true,
    })
    vim.api.nvim_set_hl(0, '@lsp.type.class.lua', {
        fg = '#f7768e',
        bold = true,
        underline = true,
    })
    vim.api.nvim_set_hl(0, '@lsp.type.function.lua', {
        fg = '#9ece6a',
        bold = true,
    })
    vim.api.nvim_set_hl(0, '@lsp.type.parameter.lua', {
        fg = '#e0af68',
        bold = true,
    })
    vim.api.nvim_set_hl(0, '@lsp.type.property.lua', {
        fg = '#7aa2f7',
        bold = true,
    })

    vim.api.nvim_set_hl(0, '@lsp.type.variable.lua', {
        fg = '#7df9ff',
        bold = true,
    })
    vim.api.nvim_set_hl(0, 'markdownCode', {
        italic = true,
    })
    vim.api.nvim_set_hl(0, 'markdownCodeBlock', {
        italic = false,
    })
    vim.api.nvim_set_hl(0, 'markdownCodeDelimiter', {
        italic = true,
    })
    vim.api.nvim_set_hl(0, 'Normal', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'NormalFloat', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'NvimTreeEndOfBuffer', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'NvimTreeNormal', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'NvimTreeVertSplit', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'Pmenu', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, '@punctuation.bracket', {
        fg = '#a4bac1',
    })
    vim.api.nvim_set_hl(0, 'Terminal', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'Search', {
        bg = '#8BCD5B',
        fg = '#202020',
    })
    vim.api.nvim_set_hl(0, 'SignColumn', {
        bg = 'none',
    })
    vim.api.nvim_set_hl(0, 'Visual', {
        bg = '#103070',
    })
end)
vim.api.nvim_create_autocmd('BufEnter', {
    once = true,
    callback = function()
        vim.api.nvim_set_hl(0, 'Comment', {
            fg = '#7f9bb3',
            italic = true,
        })
        vim.api.nvim_set_hl(0, '@comment', {
            fg = '#7f9bb3',
            italic = true,
        })
        vim.api.nvim_set_hl(0, '@comment.documentation', {
            italic = true,
            fg = '#a0c4ff',
        })
    end,
})