-- /qompassai/Diver/lua/plugins/lang/conform.lua
-- ----------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved

return {
  "stevearc/conform.nvim",
  dependencies = {
    "saghen/blink.cmp",
    "nvim-tools/none-ls.nvim",
    "nvim-tools/none-ls-extras.nvim",
  },
  lazy = false,
  event = { "BufWritePre", "BufNewFile" },
  cmd = { "ConformInfo" },
  opts = {
    formatters_by_ft = {
      ["_"] = { "trim_whitespace" },
      css = { "prettierd" },
      dockerfile = { "dockerfile_lint" },
      html = { "prettierd" },
      javascript = { "prettierd" },
      javascriptreact = { "prettierd" },
      json = { "prettierd" },
      jsonc = { "prettierd" },
      latex = { "latexindent" },
      lua = { "stylua" },
      markdown = { "marksman", "prettierd" },
      nix = { "alejandra" },
      nginx = { "nginx_config_formatter" },
      python = { "isort", "black" },
      rust = { "rustfmt", "cargo_leptos_fmt" },
      sh = { "shfmt", "beautysh" },
      sql = { "sql_formatter" },
      tex = { "latexindent" },
      toml = { "taplo" },
      tsx = { "prettierd" },
      typescript = { "prettierd" },
      typescriptreact = { "prettierd" },
      typst = { "typstfmt" },
      vue = { "prettierd" },
      yaml = { "prettierd" },
      yml = { "prettierd" },
    },
    default_format_opts = {
      lsp_format = "fallback",
    },
    format_on_save = {
      lsp_fallback = true,
      lsp_format = "fallback",
      timeout_ms = 2000,
      exclude = { "spell", "codespell" },
    },
    format_after_save = {
      lsp_format = "fallback",
    },
    log_level = vim.log.levels.ERROR,
    notify_on_error = true,
    notify_no_formatters = true,
    formatters = {
      shfmt = {
        command = "shfmt",
        args = { "-i", "2", "-ci", "-" },
        stdin = true,
      },
      beautysh = {
        command = "beautysh",
        args = {},
        stdin = true,
      },
      black = {
        prepend_args = { "--line-length", "88" },
      },
      cargo_leptos_fmt = {
        command = "cargo",
        args = { "leptosfmt" },
        stdin = false,
        condition = function(ctx)
          if not ctx or not ctx.dirname then
            return false
          end
          local cargo_toml = vim.fn.findfile("Cargo.toml", ctx.dirname .. ";")
          if cargo_toml == "" then
            return false
          end
          local lines = vim.fn.readfile(cargo_toml)
          for _, line in ipairs(lines) do
            if line:match("%f[%w]leptos%f[%W]") then
              return true
            end
          end
          return false
        end,
      },
      nginx_config_formatter = {
        command = "nginx-config-formatter",
        args = { "$FILENAME" },
        stdin = false,
      },
      stylua = {
        prepend_args = function(_, ctx)
          vim.schedule(function()
            vim.notify(
              "Formatting with stylua: " .. (ctx and ctx.filename or "unknown"),
              vim.log.levels.INFO,
              { title = "Conform" }
            )
          end)
          return { "--indent-type", "Spaces", "--indent-width", "2" }
        end,
      },
      rustfmt = {
        prepend_args = { "--edition", "2024" },
      },
      prettierd = {
        prepend_args = {
          "--print-width",
          "160",
          "--tab-width",
          "2",
        },
      },
    },
  },
  config = function(_, opts)
    require("conform").setup(opts)
    vim.keymap.set({ "n", "v" }, "<leader>f", function()
      require("conform").format({ async = true })
    end, { desc = "Format buffer" })
  end,
}
