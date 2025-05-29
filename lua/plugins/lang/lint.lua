-- /qompassai/Diver/lua/plugins/lang/nvim-lint.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
    "mfussenegger/nvim-lint",
    lazy = true,
    event = {"BufReadPost", "BufNewFile", "BufWritePre"},
    dependencies = {"nvim-tools/none-ls.nvim", "stevearc/conform.nvim"},
    config = function()
        local lint = require("lint")
        lint.linters_by_ft = {
            python = {"ruff", "mypy", "pylint", "bandit"},
            javascript = {"eslint", "biomejs"},
            javascriptreact = {"eslint", "biomejs"},
            typescript = {"eslint", "biomejs"},
            typescriptreact = {"eslint", "biomejs"},
            css = {"stylelint"},
            html = {"htmlhint", "tidy"},
            rust = {"clippy"},
            c = {"cppcheck", "clang-tidy"},
            cpp = {"cppcheck", "clang-tidy"},
            yaml = {"yamllint", "actionlint"},
            yml = {"yamllint"},
            dockerfile = {"hadolint"},
            docker = {"hadolint"},
            terraform = {"tflint", "tfsec"},
            sh = {"shellcheck", "bash"},
            bash = {"shellcheck", "bash"},
            zsh = {"shellcheck", "zsh"},
            fish = {"fish"},
            markdown = {"vale", "markdownlint", "write_good"},
            tex = {"chktex", "lacheck"},
            latex = {"chktex", "lacheck"},
            json = {"jsonlint"},
            jsonc = {"jsonlint"},
            toml = {"taplo"},
            nix = {"nix", "deadnix", "statix"},
            lua = {"luacheck", "selene"},
            sql = {"sqlfluff"},
            ["*"] = {"codespell", "typos"}
        }

        lint.linters.ruff.args = {
            "check", "--select=ALL", "--ignore=D,ANN,COM812,ISC001",
            "--line-length=88", "--output-format=json", "-"
        }
        lint.linters.mypy.args = {
            "--show-column-numbers", "--show-error-codes",
            "--show-error-context", "--no-color-output", "--no-error-summary",
            "--no-pretty", "--ignore-missing-imports"
        }
        lint.linters.eslint.args = {
            "--format", "json", "--stdin", "--stdin-filename",
            function() return vim.api.nvim_buf_get_name(0) end
        }
        vim.api.nvim_create_autocmd({
            "BufWritePost", "BufReadPost", "InsertLeave"
        }, {
            group = vim.api.nvim_create_augroup("nvim_lint", {clear = true}),
            callback = function()
                require("lint").try_lint()

                local filetype = vim.bo.filetype

                if vim.fn.match(vim.fn.expand("%:p"),
                                "secret\\|password\\|key\\|token") >= 0 then
                    require("lint").try_lint("bandit")
                end

                if vim.fn.match(vim.fn.expand("%:p"), ".github/workflows") >= 0 then
                    require("lint").try_lint("actionlint")
                end

                if vim.fn.expand("%:t"):lower():match("dockerfile") then
                    require("lint").try_lint("hadolint")
                end
            end
        })

        vim.api.nvim_create_user_command("Lint", function()
            require("lint").try_lint()
        end, {desc = "Run linter for current buffer"})
        vim.api.nvim_create_autocmd("LspNotify", {
            callback = function(args)
                if args.data.method == "textDocument/publishDiagnostics" then
                    require("lint").try_lint()
                end
            end
        })
        vim.api.nvim_create_user_command("LintWith", function(opts)
            require("lint").try_lint(opts.args)
        end, {
            desc = "Run specific linter",
            nargs = 1,
            complete = function()
                local linters = {}
                for ft, ft_linters in pairs(lint.linters_by_ft) do
                    for _, linter in ipairs(ft_linters) do
                        table.insert(linters, linter)
                    end
                end
                return vim.tbl_keys(vim.tbl_add_reverse_lookup(linters))
            end
        })
    end
}
