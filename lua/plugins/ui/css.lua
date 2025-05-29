-- ~/.config/nvim/lua/plugins/ui/css.lua
-- Modern CSS and Color Management Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
    {
        "NvChad/nvim-colorizer.lua",
        event = "BufReadPre",
        ft = {
            "css", "scss", "sass", "less", "stylus", "html", "javascript",
            "typescript", "jsx", "tsx", "vue", "svelte", "astro", "php", "lua",
            "vim"
        },
        opts = {
            filetypes = {
                "css",
                "scss",
                "sass",
                "less",
                "stylus",
                "html",
                "javascript",
                "typescript",
                "jsx",
                "tsx",
                "vue",
                "svelte",
                "astro",
                lua = {names = false} -- Disable named colors in lua files
            },
            user_default_options = {
                RGB = true, -- #RGB hex codes
                RRGGBB = true, -- #RRGGBB hex codes
                names = true, -- "Name" codes like Blue or blue
                RRGGBBAA = true, -- #RRGGBBAA hex codes
                AARRGGBB = true, -- 0xAARRGGBB hex codes
                rgb_fn = true, -- CSS rgb() and rgba() functions
                hsl_fn = true, -- CSS hsl() and hsla() functions
                css = true, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
                css_fn = true, -- Enable all CSS *functions*: rgb_fn, hsl_fn
                mode = "background", -- Set the display mode: foreground, background, virtualtext
                tailwind = true, -- Enable tailwind colors
                sass = {enable = true, parsers = {"css"}}, -- Enable sass colors
                virtualtext = "■",
                always_update = false
            },
            buftypes = {}
        },
        config = function(_, opts)
            require("colorizer").setup(opts)

            -- Auto-enable colorizer for supported filetypes
            vim.api.nvim_create_autocmd("FileType", {
                pattern = opts.filetypes,
                callback = function()
                    require("colorizer").attach_to_buffer(0)
                end
            })
        end
    }, {
        "uga-rosa/ccc.nvim",
        cmd = {
            "CccPick", "CccConvert", "CccHighlighterEnable",
            "CccHighlighterDisable", "CccHighlighterToggle"
        },
        keys = {
            {"<leader>cp", "<cmd>CccPick<cr>", desc = "Color picker"},
            {"<leader>cc", "<cmd>CccConvert<cr>", desc = "Convert color"}, {
                "<leader>ch",
                "<cmd>CccHighlighterToggle<cr>",
                desc = "Toggle color highlighter"
            }
        },
        config = function()
            local ccc = require("ccc")

            ccc.setup({
                highlighter = {
                    auto_enable = true,
                    lsp = true,
                    excludes = {"lazy", "mason", "help", "neo-tree"}
                },
                pickers = {
                    ccc.picker.hex, ccc.picker.css_rgb, ccc.picker.css_hsl,
                    ccc.picker.css_hwb, ccc.picker.css_lab, ccc.picker.css_lch,
                    ccc.picker.css_oklab, ccc.picker.css_oklch
                },
                outputs = {
                    ccc.output.hex, ccc.output.hex_short, ccc.output.css_rgb,
                    ccc.output.css_hsl, ccc.output.css_hwb, ccc.output.css_lab,
                    ccc.output.css_lch, ccc.output.css_oklab,
                    ccc.output.css_oklch
                },
                convert = {
                    {ccc.picker.hex, ccc.output.css_hsl},
                    {ccc.picker.css_rgb, ccc.output.css_hsl},
                    {ccc.picker.css_hsl, ccc.output.hex}
                },
                mappings = {
                    ["q"] = ccc.mapping.quit,
                    ["L"] = ccc.mapping.increase10,
                    ["H"] = ccc.mapping.decrease10,
                    ["l"] = ccc.mapping.increase1,
                    ["h"] = ccc.mapping.decrease1,
                    ["i"] = ccc.mapping.set_insert_mode
                }
            })
        end
    }, {
        "MaxMEllon/vim-jsx-pretty",
        ft = {"javascript", "javascriptreact", "typescript", "typescriptreact"}
    }, {
        "luckasRanarison/tailwind-tools.nvim",
        name = "tailwind-tools",
        build = ":UpdateRemotePlugins",
        ft = {
            "html", "css", "scss", "sass", "less", "javascript",
            "javascriptreact", "typescript", "typescriptreact", "vue", "svelte",
            "astro", "php", "twig"
        },
        dependencies = {"nvim-treesitter/nvim-treesitter"},
        opts = {
            document_color = {
                enabled = true, -- can be toggled by commands
                kind = "inline", -- "inline" | "foreground" | "background"
                inline_symbol = "󰝤 ", -- only used in inline mode
                debounce = 200 -- in milliseconds, only applied in insert mode
            },
            conceal = {
                enabled = false, -- can be toggled by commands
                symbol = "󱏿", -- only a single character is allowed
                highlight = { -- extmark highlight options, see :h 'highlight'
                    fg = "#38BDF8"
                }
            },
            custom_filetypes = {} -- see the extension section to learn how it works
        }
    }, {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            if opts.ensure_installed ~= "all" then
                opts.ensure_installed = vim.list_extend(
                                            opts.ensure_installed or {}, {
                        "css", "scss", "html", "javascript", "typescript",
                        "tsx", "jsx", "vue", "svelte"
                    })
            end
        end
    }, {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            local npairs = require("nvim-autopairs")
            local Rule = require("nvim-autopairs.rule")

            npairs.setup({
                check_ts = true,
                ts_config = {
                    lua = {"string", "source"},
                    javascript = {"string", "template_string"},
                    java = false
                },
                disable_filetype = {"TelescopePrompt", "spectre_panel"},
                fast_wrap = {
                    map = "<M-e>",
                    chars = {"{", "[", "(", '"', "'"},
                    pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
                    offset = 0,
                    end_key = "$",
                    keys = "qwertyuiopzxcvbnmasdfghjkl",
                    check_comma = true,
                    highlight = "PmenuSel",
                    highlight_grey = "LineNr"
                }
            })

            npairs.add_rules({
                Rule("/*", "*/", "css"), Rule("/**", "**/", "css"),
                Rule("{{", "}}", {"html", "vue", "svelte"})
            })
        end
    }
}
