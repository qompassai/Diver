-- /qompassai/Diver/lua/config/core/whichkey.lua
-- Qompass AI Diver Core WhichKey Config
---@module 'config.core.whichkey'
local WK = {}
WK.opts = {
    debug = false,
    defer = function(ctx)
        return ctx.mode == 'V' or ctx.mode == '<C-V>'
    end,
    expand = 0,
    icons = {
        breadcrumb = '»',
        colors = true,
        ellipsis = '…',
        group = '+',
        keys = { ---@type table[]
            BS = '󰁮',
            C = '󰘴 ',
            CR = '󰌑 ',
            D = '󰘳 ',
            Down = ' ',
            Esc = '󱊷 ',
            F1 = '󱊫',
            F10 = '󱊴',
            F11 = '󱊵',
            F12 = '󱊶',
            F2 = '󱊬',
            F3 = '󱊭',
            F4 = '󱊮',
            F5 = '󱊯',
            F6 = '󱊰',
            F7 = '󱊱',
            F8 = '󱊲',
            F9 = '󱊳',
            Left = ' ',
            M = '󰘵 ',
            Right = ' ',
            S = '󰘶 ',
            Space = '󱁐 ',
            Tab = '󰌒 ',
            Up = ' ',
        },
        mappings = true,
        rules = {},
        separator = '➜',
    },
    layout = {
        spacing = 3,
        width = {
            min = 20,
        },
    },
    notify = true,
    plugins = {
        marks = true,
        presets = {
            g = true,
            motions = true,
            nav = true,
            operators = true,
            text_objects = true,
            windows = true,
            z = true,
        },
        registers = true,
        spelling = {
            enabled = true,
            suggestions = 20,
        },
    },
    preset = 'modern',
    replace = {
        desc = {
            {
                '^:%s*',
                '',
            },
            {
                '^%+',
                '',
            },
            {
                '<Plug>%(?(.*)%)?',
                '%1',
            },
            {
                '<[cC]md>',
                '',
            },
            {
                '<[cC][rR]>',
                '',
            },
            {
                '<[sS]ilent>',
                '',
            },
            {
                '^call%s+',
                '',
            },
            {
                '^lua%s+',
                '',
            },
        },
        key = {
            function(key)
                local ok_view, wk_view = pcall(require, 'which-key.view')
                if not ok_view then
                    return key
                end
                return wk_view.format(key)
            end,
        },
    },
    show_help = true,
    show_keys = true,
    sort = {
        'local',
        'order',
        'group',
        'alphanum',
        'mod',
    },
    spec = {},
    triggers = {
        {
            '<auto>',
            mode = 'nixsotc',
        },
        {
            'a',
            mode = {
                'n',
                'v',
            },
        },
    },
    win = {
        no_overlap = true,
        padding = {
            1,
            2,
        },
        title = true,
        title_pos = 'center',
        zindex = 1000,
    },
}
function WK.setup(extra)
    local ok, whichkey = pcall(require, 'which-key')
    if not ok then
        vim.notify('which-key not available', vim.log.levels.WARN)
        return
    end
    whichkey.setup(vim.tbl_deep_extend('force', WK.opts, extra or {}))
    vim.keymap.set('n', '<leader>?', function()
        whichkey.show({ global = false })
    end, { desc = 'Buffer Local Keymaps (which-key)' })
end

return WK
