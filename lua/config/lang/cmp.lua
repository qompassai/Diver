-- qompassai/Diver/lua/config/lang/cmp.lua
-- Qompass AI Diver Lang Completion Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
function M.blink_cmp()
    return {
        keymap = {
            preset = 'default',
        },
        appearance = {
            nerd_font_variant = 'mono',
            kind_icons = require('lazyvim.config').icons.kinds,
        },
        completion = {
            documentation = {
                auto_show = true,
            },
            list = {
                selection = {
                    auto_insert = false,
                    preselect = true,
                },
            },
        },
        snippets = {
            preset = 'luasnip',
        },
        sources = {
            default = {
                'lazydev',
                'lsp',
                'path',
                'snippets',
                'buffer',
                'dadbod',
                'emoji',
                'dictionary',
            },
            providers = {
                lazydev = {
                    name = 'LazyDev',
                    module = 'lazydev.integrations.blink',
                    score_offset = 1001,
                },
                lsp = {
                    name = 'lsp',
                    enabled = true,
                    module = 'blink.cmp.sources.lsp',
                    min_keyword_length = 3,
                    score_offset = 2000,
                },
                path = {
                    name = 'Path',
                    enabled = true,
                    module = 'blink.cmp.sources.path',
                    score_offset = 250,
                    fallbacks = {
                        'snippets',
                        'buffer',
                    },
                    opts = {
                        trailing_slash = true,
                        label_trailing_slash = true,
                        get_cwd = function(context)
                            return vim.fn.expand(('#%d:p:h'):format(context.bufnr))
                        end,
                        show_hidden_files_by_default = true,
                    },
                },
                buffer = {
                    enabled = true,
                    name = 'Buffer',
                    max_items = 3,
                    module = 'blink.cmp.sources.buffer',
                    min_keyword_length = 3,
                    score_offset = 500,
                },
                snippets = {
                    name = 'snippets',
                    enabled = true,
                    max_items = 15,
                    min_keyword_length = 3,
                    module = 'blink.cmp.sources.snippets',
                    score_offset = 750,
                },
                dadbod = {
                    name = 'Dadbod',
                    enabled = true,
                    module = 'vim_dadbod_completion.blink',
                    min_keyword_length = 3,
                    score_offset = 85,
                },
                emoji = {
                    module = 'blink-emoji',
                    name = 'Emoji',
                    enabled = true,
                    score_offset = 93,
                    min_keyword_length = 3,
                    opts = {
                        insert = true,
                    },
                },
                dictionary = {
                    module = 'blink-cmp-dictionary',
                    name = 'Dict',
                    score_offset = 20,
                    enabled = true,
                    max_items = 8,
                    min_keyword_length = 3,
                    opts = {
                        dictionary_directories = {
                            vim.fn.expand('\'$XDG_CONFIG_HOME/nvim/lua/utils/docs/dictionary\''),
                        },
                        dictionary_files = {
                            vim.fn.expand('\'$XDG_CONFIG_HOME/nvim/lua/utils/docs/dictionary/en.utf-8.add\''),
                        },
                    },
                },
            },
        },
        cmdline = {
            enabled = true,
        },
        fuzzy = {
            frecency = {
                enabled = true,
                path = vim.fn.stdpath('state') .. '/blink/cmp/frecency.dat',
                unsafe_no_lock = false,
            },
            implementation = 'prefer_rust_with_warning',
            sorts = {
                'exact',
                'score',
                'sort_text',
            },
            use_proximity = false,
        },
    }
end

function M.lua_cmp()
    if vim.g.use_blink_cmp then
        return {
            sources = {
                {
                    name = 'lsp',
                },
                {
                    name = 'luasnip',
                },
                {
                    name = 'buffer',
                },
                {
                    name = 'nvim_lua',
                    via = 'compat',
                },
                {
                    name = 'lazydev',
                },
            },
            performance = {
                async = true,
                throttle = 50,
            },
            appearance = {
                kind_icons = require('lazyvim.config').icons.kinds, ---@type string
                nerd_font_variant = 'mono',
                use_nvim_cmp_as_default = false,
            },
            completion = {
                accept = {
                    auto_brackets = true,
                },
                menu = {
                    draw = {
                        treesitter = {
                            'lsp',
                        },
                    },
                },
                documentation = {
                    auto_show = true,
                },
            },
        }
    else
        local cmp = require('cmp') ---@type table
        return {
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({ ---@type string[]
                ['<C-b>'] = cmp.mapping.scroll_docs(-4), ---@type string[]
                ['<C-f>'] = cmp.mapping.scroll_docs(4), ---@type string[]
                ['<C-Space>'] = cmp.mapping.complete(), ---@type string[]
                ['<C-e>'] = cmp.mapping.abort(), ---@type string[]
                ['<CR>'] = cmp.mapping.confirm({ select = true }), ---@type string[]
            }),
            sources = {
                {
                    name = 'nvim_lua',
                },
                {
                    name = 'nvim_lsp',
                },
                {
                    name = 'luasnip',
                },
                {
                    name = 'buffer',
                },
            },
            experimental = {
                ghost_text = true,
            },
        }
    end
end

function M.nvim_cmp()
    local cmp = require('cmp') ---@type table
    local luasnip = require('luasnip') ---@type table
    local mappings = {
        ['<C-b>'] = cmp.mapping.scroll_docs(-4), ---@type string[]
        ['<C-f>'] = cmp.mapping.scroll_docs(4), ---@type string[]
        ['<C-Space>'] = cmp.mapping.complete(), ---@type string[]
        ['<C-e>'] = cmp.mapping.abort(), ---@type string[]
        ['<CR>'] = cmp.mapping.confirm({ ---@type string[]
            select = true,
            behavior = cmp.ConfirmBehavior.Replace, ---@type string[]
        }),
        ['<Tab>'] = cmp.mapping(function(fallback) ---@type string
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end, {
            'i',
            's',
        }),
        ['<S-Tab>'] = cmp.mapping(function(fallback) ---@type string
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, {
            'i',
            's',
        }),
    }
    cmp.setup({
        snippet = {
            expand = function(args)
                luasnip.lsp_expand(args.body)
            end,
        },
        mapping = mappings,
        sources = cmp.config.sources(), ---@type table[]
        formatting = {
            format = require('lspkind').cmp_format({ ---@type table[]
                mode = 'symbol_text',
                maxwidth = 50,
                ellipsis_char = '...',
                before = function(entry, vim_item)
                    vim_item.menu = ({ ---@type table[]
                        nvim_lsp = '[LSP]',
                        nvim_lua = '[Lua]',
                        luasnip = '[Snippet]',
                        buffer = '[Buffer]',
                        path = '[Path]',
                    })[entry.source.name]
                    return vim_item
                end,
            }),
        },
        experimental = {
            ghost_text = {
                hl_group = 'Comment',
            },
        },
        window = {
            completion = cmp.config.window.bordered({ ---@type table
                border = 'single',
                winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
            }),
            documentation = cmp.config.window.bordered({ ---@type table
                border = 'single',
                winhighlight = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
            }),
        },
    })
end

return M