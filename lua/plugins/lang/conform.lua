-- /qompassai/Diver/lua/plugins/lang/conform.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return {
  "stevearc/conform.nvim",
  dependencies = {
    "nvim-tools/none-ls.nvim",
    "nvim-tools/none-ls-extras.nvim",
  },
  lazy = true,
  event = { "BufWritePre", "BufNewFile" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      ["_"] = { "trim_whitespace" },
      asm = { "asmfmt" },
      ansible = { "ansible-lint" },
      astro = { "prettier", "biome" },
      bash = { "shfmt", "shellcheck" },
      c = { "clang_format" },
      clojure = { "cljfmt" },
      cmake = { "cmake_format" },
      conf = { "trim_whitespace" },
      cpp = { "clang_format" },
      csharp = { "csharpier" },
      css = { "biome_css", "stylelint" },
      cue = { "cue_fmt" },
      dart = { "dart_format" },
      dhall = { "dhall_format" },
      dockerfile = { "dockerfmt" },
      elixir = { "mix_format" },
      elm = { "elm_format" },
      erlang = { "erlfmt" },
      fish = { "fish_indent" },
      gleam = { "gleam_format" },
      go = { "goimports", "gofumpt" },
      groovy = { "npm_groovy_lint" },
      html = { "biome_html", "djlint", "prettier_html" },
      javascript = { "biome", "eslint_d", "prettierd" },
      javascriptreact = { "biome", "eslint_d", "prettierd" },
      json = { "biome", "jq", "prettierd" },
      jsonc = { "biome", "prettierd" },
      jsonnet = { "jsonnetfmt" },
      json5 = { "prettierd" },
      julia = { "julia_format" },
      just = { "just_fmt" },
      justfile = { "just_fmt" },
      handlebars = { "prettier" },
      haskell = { "ormolu", "fourmolu" },
      hcl = { "terraform_fmt" },
      helm = { "helm_format" },
      htmlangular = { "prettier_html" },
      htmldjango = { "djlint" },
      java = { "google-java-format" },
      kotlin = { "ktlint" },
      latex = { "tex-fmt", "latexindent" },
      lua = { "stylua", "lua-format" },
      luau = { "stylua" },
      markdown = { "prettier-markdown", "remark", "mdformat" },
      ["markdown.mdx"] = { "prettier-markdown", "remark" },
      nix = { "alejandra", "nixfmt", "nixpkgs-fmt" },
      nginx = { "nginxfmt" },
      perl = { "perltidy" },
      php = { "php_cs_fixer", "phpcbf" },
      prisma = { "prisma_format" },
      proto = { "buf" },
      protobuf = { "buf" },
      python = { "ruff_format", "ruff_organize_imports", "black", "isort" },
      pug = { "prettier" },
      r = { "styler" },
      requirements = { "ruff_format" },
      ruby = { "rubocop", "standardrb" },
      rust = { "rustfmt" },
      scala = { "scalafmt" },
      scss = { "stylelint", "prettier_css" },
      sass = { "stylelint", "prettier_css" },
      sh = { "shfmt" },
      solidity = { "prettier_solidity" },
      sql = { "sqlfluff", "sql-formatter" },
      sqlite = { "sqlfluff" },
      svelte = { "prettier", "svelte_format" },
      swift = { "swift_format" },
      tex = { "latexindent" },
      terraform = { "terraform_fmt" },
      toml = { "toml-sort", "taplo" },
      tsx = { "biome", "eslint_d", "prettierd" },
      typescript = { "biome", "eslint_d", "prettierd" },
      typescriptreact = { "biome", "eslint_d", "prettierd" },
      vue = { "prettierd" },
      yaml = { "yamlfmt", "yq", "prettier_yaml", "prettierd" },
      yml = { "yamlfmt", "yq", "prettier_yaml", "prettierd" },
      zig = { "zigfmt", "zigfmt_ast" },
      zsh = { "shfmt", "shellcheck" },
    },
    default_format_opts = { lsp_format = "fallback" },
    format_on_save = {
      lsp_fallback = true,
      lsp_format = "fallback",
      timeout_ms = 2000,
      undojoin = true,
      stop_after_first = false,
      exclude = { "spell", "codespell" },
    },
    format_after_save = {
      lsp_format = "fallback",
      async = true,
      timeout_ms = 2000,
    },
    log_level = vim.log.levels.WARN,
    notify_on_error = true,
    notify_no_formatters = false,
    formatters = {
      alejandra = {
        command = "alejandra",
        stdin = true,
        args = { "-" },
      },
      black = {
        command = "black",
        stdin = true,
        prepend_args = { "--line-length", "88" },
      },
      biome = {
        command = "biome",
        args = { "format", "--stdin-file-path", "$FILENAME" },
        stdin = true,
        prepend_args = { "--line-width", "160" },
      },
      biome_css = {
        command = "biome",
        args = { "format", "--stdin-file-path", "$FILENAME" },
        stdin = true,
        prepend_args = { "--line-width", "160" },
      },
      biome_html = {
        command = "biome",
        args = { "format", "--stdin-file-path", "$FILENAME" },
        stdin = true,
      },
      buf = {
        command = "buf",
        args = { "format", "--write" },
        stdin = false,
      },
      clang_format = {
        command = "clang-format",
        stdin = true,
        args = { "--assume-filename", "$FILENAME" },
        prepend_args = { "--style=file", "--fallback-style=llvm" }, -- or llvm
        -- prepend_args = { "--style=file", "--fallback-style=webkit" }, -- or webkit
        -- prepend_args = { "--style=file", "--fallback-style=microsoft" }, -- or microsoft
      },
      cljfmt = {
        command = "cljfmt",
        stdin = true,
        args = { "fix", "--stdin" },
      },
      cmake_format = {
        command = "cmake-format",
        stdin = true,
        args = { "-" },
      },
      csharpier = {
        command = "csharpier",
        stdin = true,
        args = {
          "--stdin-filepath",
          "$FILENAME",
          "--print-width",
          "160",
        },
      },
      crystal_format = {
        command = "crystal",
        args = { "tool", "format", "-" },
        stdin = true,
      },
      cue_fmt = {
        command = "cue",
        args = { "fmt", "-" },
        stdin = true,
      },
      dart_format = {
        command = "dart",
        args = { "format", "--stdin-name", "$FILENAME" },
        stdin = true,
        prepend_args = { "--line-length", "120" },
      },
      dhall_format = {
        command = "dhall",
        stdin = true,
        args = { "format" },
      },
      djlint = {
        command = "djlint",
        args = { "--reformat", "-" },
        stdin = true,
        prepend_args = { "--max-line-length", "160" },
      },
      dockerfmt = {
        command = "dockerfmt",
        stdin = true,
      },
      erlfmt = {
        command = "erlfmt",
        stdin = true,
        args = { "--print-width", "160", "-" },
      },
      eslint = {
        command = "eslint",
        stdin = true,
        args = { "--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME" },
      },
      eslint_d = {
        command = "eslint_d",
        args = { "--fix-to-stdout", "--stdin", "--stdin-filename", "$FILENAME" },
        stdin = true,
      },
      fish_indent = {
        command = "fish_indent",
        stdin = true,
        args = {},
      },
      fourmolu = {
        command = "fourmolu",
        args = { "--stdin-input-file", "$FILENAME" },
        stdin = true,
      },
      gleam_format = {
        command = "gleam",
        args = { "format", "--stdin" },
        stdin = true,
      },
      gofumpt = {
        command = "gofumpt",
        stdin = true,
      },
      goimports = {
        command = "goimports",
        stdin = true,
      },
      google_java_format = {
        command = "google-java-format",
        stdin = true,
        args = { "-" },
      },
      groovy_format = {
        command = "npm-groovy-lint",
        stdin = false,
        args = { "--format", "$FILENAME" },
      },
      helm_format = {
        command = "yamlfmt",
        args = { "-" },
        stdin = true,
      },
      jsonnetfmt = {
        command = "jsonnetfmt",
        stdin = true,
      },
      isort = {
        command = "isort",
        stdin = true,
        args = { "--profile", "black", "--line-length", "160", "-" },
      },
      julia_format = {
        command = "julia",
        stdin = true,
        args = {
          "-e",
          "using JuliaFormatter; print(format_text(read(stdin, String)))",
        },
      },
      juliaformatter = {
        command = "julia",
        stdin = false,
        args = {
          "-e",
          'using JuliaFormatter; format("$FILENAME")',
        },
      },
      jq = {
        command = "jq",
        stdin = true,
        args = { "--tab", "." },
      },
      just_fmt = {
        command = "just",
        args = { "--fmt", "--unstable" },
        stdin = false,
      },
      ktfmt = {
        command = "ktfmt",
        stdin = true,
        args = { "--stdin", "--kotlinlang-style" },
      },
      ktlint = {
        command = "ktlint",
        stdin = true,
        args = { "--format", "--stdin" },
      },
      latexindent = {
        command = "latexindent",
        stdin = true,
        args = {
          "-",
          "--silent",
          "--local",
        },
      },
      mdformat = {
        command = "mdformat",
        stdin = true,
        args = {
          "--wrap",
          "160",
          "--end-of-line",
          "lf",
          "--number",
          "--extensions",
          "tables,gfm,admonition,mkdocs",
          "--align-semantic-breaks-in-lists",
          "-",
        },
      },
      mix_format = {
        command = "mix",
        args = { "format", "-" },
        stdin = true,
      },
      nginxfmt = {
        command = "nginxfmt",
        stdin = true,
        args = { "--pipe" },
      },
      nixfmt = {
        command = "nixfmt",
        stdin = true,
        args = {},
      },
      nixpkgs_fmt = {
        command = "nixpkgs-fmt",
        stdin = true,
        args = {},
      },
      ocamlformat = {
        command = "ocamlformat",
        args = { "--name", "$FILENAME", "-" },
        stdin = true,
      },
      npm_groovy_lint = {
        command = "npm-groovy-lint",
        stdin = true,
        args = { "--format", "--stdin" },
      },
      perltidy = {
        command = "perltidy",
        stdin = true,
        args = {
          "-st",
          "-i=2",
          "-l=160",
        },
      },
      php_cs_fixer = {
        command = "php-cs-fixer",
        stdin = true,
        args = { "fix", "--using-cache=no", "$FILENAME" },
      },
      phpcbf = {
        command = "phpcbf",
        stdin = true,
        args = { "--standard=PSR12" },
      },
      prettier_css = {
        command = "prettier",
        args = { "--stdin-filepath", "$FILENAME" },
        stdin = true,
        prepend_args = {
          "--parser",
          "css",
          "--print-width",
          "160",
          "--tab-width",
          "2",
          "--single-quote",
          "false",
        },
      },
      prettierd = {
        command = "prettierd",
        args = { "--stdin-filepath", "$FILENAME" },
        stdin = true,
      },
      prettier_html = {
        command = "prettier",
        stdin = true,
        args = { "--stdin-filepath", "$FILENAME" },
        prepend_args = { "--parser", "html", "--print-width", "160", "--tab-width", "2" },
      },
      ["prettier-markdown"] = {
        command = "prettier",
        stdin = true,
        args = { "--stdin-filepath", "$FILENAME" },
        prepend_args = { "--parser", "markdown", "--print-width", "160", "--tab-width", "2" },
      },
      prettier_solidity = {
        command = "prettier",
        stdin = true,
        args = { "--stdin-filepath", "$FILENAME" },
        prepend_args = {
          "--parser",
          "solidity",
          "--print-width",
          "160",
          "--tab-width",
          "2",
        },
      },
      prettier_yaml = {
        command = "prettier",
        stdin = true,
        args = { "--parser", "yaml" },
      },
      prisma_format = {
        command = "prisma",
        stdin = false,
        args = { "format" },
      },
      ["prisma-fmt"] = {
        command = "prisma-fmt",
        stdin = true,
        args = { "--stdin" },
      },
      remark = {
        command = "remark",
        stdin = true,
        args = { "--no-color", "--silent" },
      },
      ruff = {
        command = "ruff",
        args = { "format", "--stdin-filename", "$FILENAME" },
        stdin = true,
      },
      ruff_format = {
        command = "ruff",
        stdin = true,
        args = { "format", "--stdin-filename", "$FILENAME", "-" },
      },
      ruff_organize_imports = {
        command = "ruff",
        stdin = true,
        args = { "check", "--select", "I", "--fix", "--stdin-filename", "$FILENAME", "-" },
      },
      rustfmt = {
        prepend_args = {
          "--edition=2024",
          "--emit=stdout",
          "--color=never",
        },
      },
      shfmt = {
        command = "shfmt",
        args = { "-i", "2", "-ci", "-" },
        stdin = true,
      },
      rubocop = {
        command = "rubocop",
        stdin = true,
        args = { "--auto-correct", "-f", "quiet", "--stdin", "$FILENAME" },
      },
      shellcheck = {
        command = "shellcheck",
        stdin = true,
        args = { "--format=diff", "-" },
      },
      scalafmt = {
        command = "scalafmt",
        stdin = true,
        args = { "--stdin" },
      },
      stylelint = {
        command = "stylelint",
        args = { "--fix", "--stdin", "--stdin-filename", "$FILENAME" },
        stdin = true,
      },
      standardrb = {
        command = "standardrb",
        stdin = true,
        args = { "--fix", "--stdin", "$FILENAME" },
      },
      stylua = {
        command = "stylua",
        stdin = true,
        prepend_args = function(_, ctx)
          local filename = ctx and ctx.filename or ""
          local is_openresty = filename:match("/nginx/") or filename:match("/openresty/")
          return {
            "--indent-type",
            "Spaces",
            "--indent-width",
            "2",
            "--column-width",
            "160",
          }
        end,
      },
      ["lua-format"] = {
        command = "lua-format",
        stdin = true,
        prepend_args = {
          "--indent-width=2",
          "--tab-width=2",
          "--use-tab=false",
          "--column-limit=160",
          "--continuation-indent-width=2",
          "--spaces-before-call=1",
          "--keep-simple-control-block-one-line=false",
          "--keep-simple-function-one-line=false",
          "--break-before-function-call-rp=false",
          "--break-before-function-def-rp=false",
          "--chop-down-table=false",
        },
      },
      styler = {
        command = "Rscript",
        stdin = true,
        args = { "-e", "styler::style_text(readLines('stdin'))" },
      },
      sqlfluff = {
        command = "sqlfluff",
        stdin = true,
        args = { "format", "--dialect", "postgres", "-" },
        cwd = function()
          return vim.fn.getcwd()
        end,
      },
      ["sql-formatter"] = {
        command = "sql-formatter",
        stdin = true,
        args = { "--language", "postgresql" },
      },
      svelte_format = {
        command = "prettier",
        args = { "--plugin-search-dir=.", "--parser", "svelte" },
        stdin = true,
      },
      swift_format = {
        command = "swiftformat",
        stdin = true,
        args = { "--stdinpath", "$FILENAME" },
        prepend_args = { "--indent", "2", "--allman", "false" },
      },
      swiftui = { "swift_format" },
      terraform_fmt = {
        command = "terraform",
        args = { "fmt", "-" },
        stdin = true,
      },
      taplo = {
        command = "taplo",
        stdin = true,
        args = { "format", "-" },
      },
      ["tex-fmt"] = {
        command = "tex-fmt",
        stdin = true,
        args = { "--stdin" },
      },
      ["toml-sort"] = {
        command = "toml-sort",
        stdin = true,
        args = {},
      },
      xmllint = {
        command = "xmllint",
        args = { "--format", "-" },
        stdin = true,
      },
      yamlfmt = {
        command = "yamlfmt",
        stdin = true,
        args = { "-" },
      },
      yq = {
        command = "yq",
        stdin = true,
        args = { "." },
      },
      zigfmt = {
        command = "zig",
        args = { "fmt", "--stdin" },
        stdin = true,
        exit_codes = { 0, 1 },
      },
      zigfmt_check = {
        command = "zig",
        args = { "fmt", "--check", "--stdin" },
        stdin = true,
        exit_codes = { 0, 1 },
      },
      zigfmt_ast = {
        command = "zig",
        args = { "fmt", "--ast-check", "--stdin" },
        stdin = true,
        exit_codes = { 0, 1 },
      },
    },
  },
  vim.keymap.set({ "n", "v" }, "<leader>lf", function()
    require("conform").format({ async = true }, function()
      require("lint").try_lint()
    end)
  end, { desc = "Format and lint" }),
  config = function(_, opts)
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "*.lua",
      callback = function()
        print("BufWritePre triggered for Lua file")
        local formatters = require("conform").list_formatters()
        print("Available formatters:", vim.inspect(formatters))
      end,
    })
    require("conform").setup(opts)
    vim.keymap.set({ "n", "v" }, "<leader>f", function()
      require("conform").format({ async = true })
    end, { desc = "Format buffer" })
  end,
}
