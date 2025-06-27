---~/.config/nvim/lua/config/lang/conform.lua
local M = {}

---@return table
function M.blink_config()
    return {
        keymap = {preset = "default"},
        appearance = {
            nerd_font_variant = "mono",
            kind_icons = require("lazyvim.config").icons.kinds
        },
        completion = {documentation = {auto_show = true}},
        snippets = {preset = "luasnip"},
        sources = {
            default = {
                "lsp", "path", "snippets", "buffer", "dadbod", "emoji",
                "dictionary"
            },
            per_filetype = {lua = {"lsp", "nvim_lua", "snippets"}},
            providers = {
                lsp = {
                    name = "lsp",
                    enabled = true,
                    module = "blink.cmp.sources.lsp",
                    kind = "LSP",
                    min_keyword_length = 2,
                    score_offset = 1000
                },
                path = {
                    name = "Path",
                    module = "blink.cmp.sources.path",
                    score_offset = 250,
                    fallbacks = {"snippets", "buffer"},
                    opts = {
                        trailing_slash = false,
                        label_trailing_slash = true,
                        get_cwd = function(context)
                            return vim.fn.expand(("#%d:p:h"):format(
                                                     context.bufnr))
                        end,
                        show_hidden_files_by_default = true
                    }
                },
                buffer = {
                    name = "Buffer",
                    enabled = true,
                    max_items = 3,
                    module = "blink.cmp.sources.buffer",
                    min_keyword_length = 2,
                    score_offset = 500
                },
                snippets = {
                    name = "snippets",
                    enabled = true,
                    max_items = 15,
                    min_keyword_length = 2,
                    module = "blink.cmp.sources.snippets",
                    score_offset = 750
                },
                dadbod = {
                    name = "Dadbod",
                    module = "vim_dadbod_completion.blink",
                    min_keyword_length = 2,
                    score_offset = 85
                },
                emoji = {
                    module = "blink-emoji",
                    name = "Emoji",
                    score_offset = 93,
                    min_keyword_length = 2,
                    opts = {insert = true}
                },
                dictionary = {
                    module = "blink-cmp-dictionary",
                    name = "Dict",
                    score_offset = 20, -- the higher the number, the higher the priority
                    -- https://github.com/Kaiser-Yang/blink-cmp-dictionary/issues/2
                    enabled = true,
                    max_items = 8,
                    min_keyword_length = 3,
                    opts = {
                        -- -- The dictionary by default now uses fzf, make sure to have it
                        -- -- installed
                        -- -- https://github.com/Kaiser-Yang/blink-cmp-dictionary/issues/2
                        --
                        -- Do not specify a file, just the path, and in the path you need to
                        -- have your .txt files
                        dictionary_directories = {
                            vim.fn.expand(
                                "~/github/dotfiles-latest/dictionaries")
                        },
                        -- Notice I'm also adding the words I add to the spell dictionary
                        dictionary_files = {
                            vim.fn.expand(
                                "~/github/dotfiles-latest/neovim/neobean/spell/en.utf-8.add"),
                            vim.fn
                                .expand(
                                "~/github/dotfiles-latest/neovim/neobean/spell/es.utf-8.add")
                        }
                    }
                },
                fuzzy = {implementation = "lua"}
            }
        }
    }
end

function M.nvim_cmp_setup()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    local mappings = {
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({
            select = true,
            behavior = cmp.ConfirmBehavior.Replace
        }),
        ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            else
                fallback()
            end
        end, {"i", "s"}),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, {"i", "s"})
    }
    vim.lsp.completion.enable = false
    cmp.setup({
        snippet = {expand = function(args) luasnip.lsp_expand(args.body) end},
        mapping = mappings,
        sources = cmp.config.sources({
            {name = "nvim_lsp", priority = 1000},
            {name = "luasnip", priority = 750},
            {name = "buffer", priority = 500}, {name = "path", priority = 250}
        }),
        formatting = {
            format = require("lspkind").cmp_format({
                mode = "symbol_text",
                maxwidth = 50,
                ellipsis_char = "...",
                before = function(entry, vim_item)
                    vim_item.menu = ({
                        nvim_lsp = "[LSP]",
                        nvim_lua = "[Lua]",
                        luasnip = "[Snippet]",
                        buffer = "[Buffer]",
                        path = "[Path]"
                    })[entry.source.name]
                    return vim_item
                end
            })
        },
        experimental = {ghost_text = {hl_group = "Comment"}},
        window = {
            completion = cmp.config.window.bordered({
                border = "single",
                winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
            }),
            documentation = cmp.config.window.bordered({
                border = "single",
                winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"
            })
        }
    })
    cmp.setup.filetype("lua", {
        sources = cmp.config.sources({
            {name = "nvim_lua", priority = 1100},
            {name = "nvim_lsp", priority = 1000},
            {name = "luasnip", priority = 900},
            {name = "buffer", priority = 800}
        })
    })

    cmp.setup.filetype({"typescript", "typescriptreact"}, {
        sources = cmp.config.sources({
            {name = "nvim_lsp", priority = 1000},
            {name = "luasnip", priority = 900},
            {name = "buffer", priority = 800}
        })
    })
    cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({{name = "path"}, {name = "cmdline"}})
    })
    cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {{name = "buffer"}}
    })
end

return M
