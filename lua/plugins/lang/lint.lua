-- /qompassai/Diver/lua/plugins/lang/nvim-lint.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
  "mfussenegger/nvim-lint",
  lazy = true,
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  dependencies = { "nvim-tools/none-ls.nvim", "stevearc/conform.nvim" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      ["*"] = { "codespell", "typos" },
      asm = { "asm-linter" },
      bash = { "bash", "bashate", "shellcheck" },
      c = { "clang-tidy", "cpplint", "cppcheck", "flawfinder" },
      clojure = { "clj-kondo" },
      coffeescript = { "coffeelint" },
      cpp = { "clang-tidy", "cpplint", "cppcheck", "flawfinder" },
      csharp = { "csharpier", "roslynator" },
      css = { "csslint", "stylelint" },
      dart = { "dartanalyzer", "dartfmt" },
      docker = { "hadolint" },
      dockerfile = { "hadolint" },
      elixir = { "credo" },
      erlang = { "erl_lint" },
      fish = { "fish" },
      go = { "gofmt", "golangci-lint", "golint", "gosec", "govet", "ineffassign" },
      groovy = { "codeNarc" },
      haskell = { "hlint" },
      html = { "htmlcs", "htmlhint", "tidy" },
      java = { "checkstyle", "findbugs", "pmd", "spotbugs" },
      javascript = { "biomejs", "eslint", "jshint" },
      javascriptreact = { "biomejs", "eslint", "jshint" },
      json = { "jsonlint" },
      jsonc = { "jsonlint" },
      kotlin = { "ktlint" },
      latex = { "chktex", "lacheck" },
      lua = { "luacheck", "selene" },
      markdown = { "markdownlint", "textlint", "vale", "write_good" },
      nix = { "deadnix", "nix", "statix" },
      perl = { "perlcritic" },
      php = { "phpcs", "phpmd" },
      powershell = { "PSScriptAnalyzer" },
      python = { "bandit", "flake8", "mypy", "pycodestyle", "pydocstyle", "pyflakes", "pylint", "ruff" },
      r = { "lintr" },
      ruby = { "brakeman", "reek", "rubocop" },
      rust = { "clippy" },
      scala = { "scalafmt" },
      sh = { "bash", "bashate", "shellcheck" },
      sql = { "sqlfluff", "sqlint" },
      swift = { "swiftlint" },
      terraform = { "tfsec", "tflint" },
      tex = { "chktex", "lacheck" },
      toml = { "taplo" },
      typescript = { "biomejs", "eslint", "jshint" },
      typescriptreact = { "biomejs", "eslint", "jshint" },
      vue = { "eslint-plugin-vue" },
      xml = { "xmllint" },
      yaml = { "actionlint", "cfn-lint", "yamllint" },
      yml = { "yamllint" },
      zig = { "zigfmt" },
      zsh = { "shellcheck", "zsh" },
    }

    lint.linters.eslint = lint.linters.eslint or {}
    lint.linters.eslint.args = {
      "--format",
      "json",
      "--stdin",
      "--stdin-filename",
      function()
        return vim.api.nvim_buf_get_name(0)
      end,
    }

    lint.linters.mypy = lint.linters.mypy or {}
    lint.linters.mypy.args = {
      "--ignore-missing-imports",
      "--no-color-output",
      "--no-error-summary",
      "--no-pretty",
      "--show-column-numbers",
      "--show-error-codes",
      "--show-error-context",
    }

    lint.linters.ruff = lint.linters.ruff or {}
    lint.linters.ruff.args = {
      "check",
      "--ignore=D,ANN,COM812,ISC001",
      "--line-length=88",
      "--output-format=json",
      "--select=ALL",
      "-",
    }

    local lint_augroup = vim.api.nvim_create_augroup("nvim_lint", { clear = true })

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function()
        require("lint").try_lint()
        local filepath = vim.fn.expand("%:p")
        local filename = vim.fn.expand("%:t"):lower()
        if vim.fn.match(filepath, "secret\\|password\\|key\\|token") >= 0 then
          require("lint").try_lint("bandit")
        end
        if vim.fn.match(filepath, ".github/workflows") >= 0 then
          require("lint").try_lint("actionlint")
        end
        if filename:match("dockerfile") then
          require("lint").try_lint("hadolint")
        end
      end,
    })

    vim.api.nvim_create_autocmd("LspNotify", {
      group = lint_augroup,
      callback = function(args)
        if args.data.method == "textDocument/publishDiagnostics" then
          require("lint").try_lint()
        end
      end,
    })

    vim.api.nvim_create_user_command("Lint", function()
      require("lint").try_lint()
    end, { desc = "Run linter for current buffer" })

    vim.api.nvim_create_user_command("LintWith", function(opts)
      require("lint").try_lint(opts.args)
    end, {
      desc = "Run specific linter",
      nargs = 1,
      complete = function()
        local linters = {}
        for _, ft_linters in pairs(lint.linters_by_ft) do
          for _, linter in ipairs(ft_linters) do
            linters[linter] = true
          end
        end
        return vim.tbl_keys(linters)
      end,
    })
    vim.keymap.set({ "n", "v" }, "<leader>ll", function()
      require("lint").try_lint()
    end, { desc = "Lint current buffer" })
    vim.keymap.set({ "n", "v" }, "<leader>lf", function()
      require("conform").format({ async = true }, function()
        require("lint").try_lint()
      end)
    end, { desc = "Format and lint" })
  end,
}
