-- /qompassai/Diver/lua/ui/line.lua
-- Qompass AI LuaLine Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local function encoding_with_bom()
    local enc = vim.bo.fenc ~= '' and vim.bo.fenc or vim.o.enc
    if enc == 'utf-8' and not vim.bo.bomb then
        return ''
    end
    local label = enc
    if vim.bo.bomb then
        label = label .. ' [BOM]'
    end
    return label
end
local code_action_available = false
vim.api.nvim_create_autocmd('LspNotify', {
    callback = function(args)
        if args.data and args.data.method == 'textDocument/publishDiagnostics' then
            local bufnr = args.buf
            local diags = vim.diagnostic.get(bufnr)
            code_action_available = #diags > 0
        end
    end,
})
local function code_action_status()
    if not vim.lsp.buf.server_ready() then
        return ''
    end
    if code_action_available then
        return '💡 CA'
    end
    return ''
end
require('types.ui.line')
require('lualine').setup({
    options = {
        icons_enabled = true,
        theme = 'auto',
        component_separators = {
            left = '',
            right = '',
        },
        section_separators = {
            left = '',
            right = '',
        },
        disabled_filetypes = {
            statusline = {},
            winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = false,
        globalstatus = true,
        refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
            refresh_time = 16,
            events = {
                'BufEnter',
                'BufWritePost',
                'CursorMoved',
                'CursorMovedI',
                'FileChangedShellPost',
                'FileType',
                'ModeChanged',
                'SessionLoadPost',
                'VimResized',
                'WinEnter',
            },
        },
    },
    sections = {
        lualine_a = {
            {
                'mode',
                icons_enabled = true,
                icon = nil,
            },
        },
        lualine_b = {
            {
                'branch',
                icon = '',
            },
            {
                'diff',
                colored = true,
                diff_color = {
                    added = 'LuaLineDiffAdd',
                    modified = 'LuaLineDiffChange',
                    removed = 'LuaLineDiffDelete',
                },
                symbols = {
                    added = '+',
                    modified = '~',
                    removed = '-',
                },
                source = nil,
            },
            {
                'diagnostics',
                sources = {
                    'nvim_lsp',
                    'nvim_diagnostic',
                    'nvim_workspace_diagnostic',
                },
                sections = {
                    'error',
                    'warn',
                    'info',
                    'hint',
                },
                diagnostics_color = {
                    error = {
                        fg = '#e06c75',
                    },
                    warn = {
                        fg = '#e5c07b',
                    },
                    info = {
                        fg = '#56b6c2',
                    },
                    hint = {
                        fg = '#98c379',
                    },
                },
                symbols = {
                    error = ' ',
                    warn = ' ',
                    info = ' ',
                    hint = ' ',
                },
                always_visible = false,
                colored = true,
                update_in_insert = true,
            },
        },
        lualine_c = {
            {
                'searchcount',
                maxcount = 999,
                timeout = 500,
            },
            {
                function()
                    local wc = vim.fn.wordcount()
                    local line_count = vim.api.nvim_buf_line_count(0)
                    return string.format('%d words, %d chars, %d lines', wc.words, wc.chars, line_count)
                end,
                icon = '# ',
            },
        },
        lualine_x = {
            {
                'location',
            },
            encoding_with_bom,
            code_action_status,
        },
        lualine_y = {
            {
                'progress',
            },
        },
        lualine_z = {
            {
                function()
                    return os.date('%H:%M:%S')
                end,
                refresh = 1000,
            },
            {
                function()
                    return os.date('%Y-%m-%d')
                end,
            },
        },
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
            {
                'filename',
            },
        },
        lualine_x = {
            {
                'location',
            },
        },
        lualine_y = {},
        lualine_z = {},
    },
    tabline = {
        lualine_a = {
            {
                'tabs',
                tab_max_length = 40,
                max_length = vim.o.columns / 3,
                mode = 0,
                use_mode_colors = true,
            },
        },
        lualine_b = {
            'branch',
        },
        lualine_c = {
            {
                'filename',
                file_status = true,
                newfile_status = true,
                path = 2,
                shorting_target = 40,
                symbols = {
                    modified = '[+]',
                    readonly = '[-]',
                    unnamed = '[No Name]',
                    newfile = '[New]',
                },
                {
                    'filetype',
                    colored = true,
                    icon_only = false,
                    icon = {
                        align = 'right',
                    },
                },
                {
                    'fileformat',
                    symbols = {
                        unix = ' ',
                        dos = ' ',
                        mac = ' ',
                    },
                },
            },
        },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
    },
    winbar = {
        lualine_a = {},
        lualine_b = {
            code_action_status,
        },
        lualine_c = {
            {
                'windows',
                mode = 2,
                use_mode_colors = true,
                max_length = vim.o.columns * 2 / 3,
            },
            {
                'lsp_status',
                icon = '',
                symbols = {
                    spinner = {
                        '⠋',
                        '⠙',
                        '⠹',
                        '⠸',
                        '⠼',
                        '⠴',
                        '⠦',
                        '⠧',
                        '⠇',
                        '⠏',
                    },
                    done = '✓',
                    separator = ' ',
                },
                ignore_lsp = {},
            },
            {
                'branch',
            },
        },
        lualine_x = {
            {
                encoding_with_bom,
            },
        },
        lualine_y = {
            {
                function()
                    local buf = vim.api.nvim_get_current_buf()
                    local ft = vim.bo[buf].filetype
                    local ts_active = vim.treesitter.highlighter.active[buf]
                    if ts_active then
                        local has_parser, lang = pcall(vim.treesitter.language.get_lang, ft)
                        if has_parser and lang then
                            local parser_ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
                            if parser_ok and parser then
                                local tree_ok, trees = pcall(parser.trees, parser)
                                local tree_count = (tree_ok and trees) and #trees or 0
                                if tree_count > 1 then
                                    return '󰐅 ' .. lang .. string.format('[%d]', tree_count)
                                else
                                    return '󰐅 ' .. lang
                                end
                            else
                                return '󰐅 ' .. lang
                            end
                        else
                            return '󰐅 TS'
                        end
                    elseif ft ~= '' then
                        local has_parser = pcall(vim.treesitter.language.get_lang, ft)
                        if has_parser then
                            return '󰐅 TS⚠'
                        else
                            return '󰐅 ' .. ft .. '✗'
                        end
                    else
                        return ''
                    end
                end,
                color = {
                    fg = '#7df9ff',
                },
            },
        },
        lualine_z = {},
    },
    inactive_winbar = {},
    extensions = {
        'fzf',
        'lazy',
        'neo-tree',
        'nvim-dap-ui',
        'nvim-tree',
        'quickfix',
        'toggleterm',
        'trouble',
    },
})
return M