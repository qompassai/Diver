-- /qompassai/Diver/lua/plugins/ui/noice.lua
-- Qompass AI Diver Noice Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = {
        lsp = {
            override = {
                ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
                ['vim.lsp.util.stylize_markdown'] = true,
                ['cmp.entry.get_documentation'] = true
            },
            hover = {enabled = true},
            signature = {
                enabled = true,
                auto_open = {
                    enabled = true,
                    trigger = true,
                    luasnip = true,
                    throttle = 50
                },
                view = nil,
                routes = {
                    {
                        filter = {
                            event = 'msg_show',
                            kind = '',
                            find = 'which%-key'
                        },
                        opts = {skip = true}
                    }
                }
            }
        },
        presets = {
            bottom_search = true,
            command_palette = true,
            long_message_to_split = true,
            inc_rename = true,
            lsp_doc_border = true
        },
        views = {
            cmdline_popup = {
                relative = 'editor',
                position = {row = '50%', col = '50%'},
                size = {width = 60, height = 'auto'},
                border = {style = 'rounded', padding = {0, 1}},
                win_options = {
                    winhighlight = {
                        Normal = 'Normal',
                        FloatBorder = 'DiagnosticInfo'
                    }
                }
            }
        },
        routes = {
            {filter = {event = 'BufWinEnter'}, opts = {skip = true}},
            {filter = {event = 'BufEnter'}, opts = {skip = true}}
        }
    },
    dependencies = {
        'MunifTanjim/nui.nvim',
        'rcarriga/nvim-notify',
    },
    config = function(_, opts)
        require('noice').setup(opts)
        require('notify').setup({
            on_open = function(win)
                vim.api.nvim_set_option_value('winhl',
                                              'Normal:MyNotifyBackground',
                                              {scope = 'local', win = win})
            end,
            background_colour = '#000000',
            highlights = {
                NotifyERRORBorder = {guifg = '#8A1F1F'},
                NotifyWARNBorder = {guifg = '#79491D'},
                NotifyINFOBorder = {guifg = '#4F6752'},
                NotifyDEBUGBorder = {guifg = '#8B8B8B'},
                NotifyTRACEBorder = {guifg = '#4F3552'},
                NotifyERRORIcon = {guifg = '#F70067'},
                NotifyWARNIcon = {guifg = '#F79000'},
                NotifyINFOIcon = {guifg = '#A9FF68'},
                NotifyDEBUGIcon = {guifg = '#8B8B8B'},
                NotifyTRACEIcon = {guifg = '#D484FF'},
                NotifyERRORTitle = {guifg = '#F70067'},
                NotifyWARNTitle = {guifg = '#F79000'},
                NotifyINFOTitle = {guifg = '#A9FF68'},
                NotifyDEBUGTitle = {guifg = '#8B8B8B'},
                NotifyTRACETitle = {guifg = '#D484FF'}
            }
        })
        vim.api.nvim_create_user_command('Mason', function()
            require('mason.ui').open()
        end, {})
        vim.api.nvim_create_user_command('MasonInstall', function(args)
            require('mason.api.command').MasonInstall(args.fargs)
        end, {nargs = '+'})
        vim.api.nvim_create_user_command('MasonUpdate', function()
            require('mason.api.command').MasonUpdate()
        end, {})
        vim.api.nvim_create_user_command('NullLsInfo', function()
            require('null-ls').info()
        end, {})
        vim.api.nvim_create_user_command('Shellharden', function(args)
            local filename = args.args
            if filename == '' then filename = vim.fn.expand('%') end
            vim.fn.system('shellharden --transform ' .. filename)
            vim.cmd('edit!')
        end, {nargs = '?'})
        vim.api.nvim_create_user_command('Z', function(args)
            local query = args.args
            local output = vim.fn.system('zoxide query ' .. query)
            output = vim.fn.trim(output)
            if vim.fn.isdirectory(output) == 1 then
                vim.cmd('cd ' .. output)
                print('Changed directory to: ' .. output)
            else
                print('Directory not found: ' .. query)
            end
        end, {nargs = '?'})
    end
}
