-- /qompassai/Diver/lua/plugins/ui/noice.lua
-- Qompass AI Diver Noice Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'folke/noice.nvim',
    lazy = false,
    priority = 1000,
    opts = {
        lsp = {
            override = {
                ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
                ['vim.lsp.util.stylize_markdown'] = true,
                ['cmp.entry.get_documentation'] = true,
            },
            hover = { enabled = true },
            signature = {
                enabled = true,
                auto_open = {
                    enabled = true,
                    trigger = true,
                    luasnip = true,
                    throttle = 50,
                },
                routes = {
                    { filter = { event = 'msg_show', find = 'which%-key' }, opts = { skip = true } },
                },
            },
        },
        presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            inc_rename = true,
            lsp_doc_border = true,
        },
        views = {
            cmdline_popup = {
                relative = 'editor',
                position = { row = 50, col = 50 },
                size = { width = 60, height = 'auto' },
                border = { style = 'rounded', padding = { 0, 1 } },
                win_options = {
                    winhighlight = 'Normal:Normal,FloatBorder:DiagnosticInfo',
                },
            },
        },
        routes = {
            { filter = { event = 'msg_show', find = 'written' }, opts = { skip = true, replace = true } },
            { filter = { event = 'msg_show', kind = 'search_count' }, opts = { skip = true } },
        },
    },
    dependencies = {
        'MunifTanjim/nui.nvim',
        {
            'rcarriga/nvim-notify',
            opts = {
                background_colour = '#000000',
                fps = 30,
                stages = 'fade_in_slide_out',
                merge_duplicates = true,
                timeout = 3000,
                top_down = false,
                render = 'compact',
                icons = {
                    ERROR = '',
                    WARN = '',
                    INFO = '',
                    DEBUG = '',
                    TRACE = '✎',
                },
            },
        },
    },
}