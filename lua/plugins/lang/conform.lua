-- /qompassai/Diver/lua/plugins/lang/conform.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
    "stevearc/conform.nvim",
    dependencies = {
        "saghen/blink.cmp", "nvim-tools/none-ls.nvim",
        "nvim-tools/none-ls-extras.nvim"
    },
    lazy = false,
    event = {"BufWritePre", "BufNewFile"},
    cmd = {"ConformInfo"},
    opts = {
        formatters_by_ft = {
            ["_"] = {"trim_whitespace"},
            css = {"prettierd"},
            dockerfile = {"dockerfmt"},
            html = {"prettierd"},
            javascript = {"biome", "prettierd"},
            javascriptreact = {"prettierd"},
            json = {"prettierd"},
            jsonc = {"prettierd"},
            latex = {"latexindent"},
            lua = {"stylua", "lua-format"},
            markdown = {"mdformat", "prettierd"},
            nix = {"alejandra", "nixfmt"},
            nginx = {"nginx_config_formatter"},
            python = {"ruff", "isort", "black"},
            rust = {"rustfmt"},
            sh = {"shfmt"},
            sql = {"sqlfluff", "sql_formatter"},
            tex = {"latexindent"},
            toml = {"taplo"},
            tsx = {"biome", "prettierd"},
            typescript = {"biome", "prettierd"},
            typescriptreact = {"biome", "prettierd"},
            typst = {"typstfmt"},
            vue = {"prettierd"},
            yaml = {"prettierd"},
            yml = {"prettierd"}
        },
        default_format_opts = {lsp_format = "fallback"},
        format_on_save = {
            lsp_fallback = true,
            lsp_format = "fallback",
            timeout_ms = 2000,
            exclude = {"spell", "codespell"}
        },
        format_after_save = {lsp_format = "fallback"},
        log_level = vim.log.levels.ERROR,
        notify_on_error = true,
        notify_no_formatters = true,
        formatters = {
            alejandra = {command = "alejandra", stdin = true},
            shfmt = {
                command = "shfmt",
                args = {"-i", "2", "-ci", "-"},
                stdin = true
            },
            black = {prepend_args = {"--line-length", "88"}},
            nginx_config_formatter = {
                command = "nginx-config-formatter",
                args = {"$FILENAME"},
                stdin = false
            },
            stylua = {
                prepend_args = function(_, ctx)
                    vim.schedule(function()
                        vim.notify("Formatting with stylua: " ..
                                       (ctx and ctx.filename or "unknown"),
                                   vim.log.levels.INFO, {title = "Conform"})
                    end)
                    return {"--indent-type", "Spaces", "--indent-width", "2"}
                end
            },
            rustfmt = {prepend_args = {"--edition", "2024"}},
            prettierd = {
                prepend_args = {"--print-width", "160", "--tab-width", "2"},
                stdin = true
            }
        }
    },
    vim.keymap.set({"n", "v"}, "<leader>lf", function()
        require("conform").format({async = true},
                                  function() require("lint").try_lint() end)
    end, {desc = "Format and lint"}),
    config = function(_, opts)
        require("conform").setup(opts)
        vim.keymap.set({"n", "v"}, "<leader>f", function()
            require("conform").format({async = true})
        end, {desc = "Format buffer"})
    end
}
