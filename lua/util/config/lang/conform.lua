---~/.config/nvim/lua/config/lang/conform.lua
---------------------------------------------
---@module "conform"
local M = {}
---@class conform.Config

---@param opts conform.Config|nil
function M.setup(opts)
  opts = opts or {}
  return {
    formatters_by_ft = opts.formatters_by_ft or {
      ["_"] = { "trim_whitespace" },
      ansible = { "ansible-lint" },
      css = { "prettierd" },
      dockerfile = { "dockerfile_lint" },
      html = { "prettierd" },
      javascript = { "prettierd" },
      javascriptreact = { "prettierd" },
      json = { "jsonls", "prettierd" },
      latex = { "latexindent" },
      lua = { "stylua" },
      luau = { "stylua" },
      markdown = { "marksman", "prettierd" },
      nginx = { "nginx_config_formatter" },
      python = { "isort", "black" },
      rust = { "rustfmt", "cargo_leptos_fmt" },
      sh = { "shfmt", "beautysh" },
      sql = { "sql_formatter", "sqlfluff" },
      tex = { "latexindent" },
      toml = { "taplo" },
      tsx = { "prettierd" },
      typescript = { "prettierd" },
      typescriptreact = { "prettierd" },
      typst = { "typstfmt" },
      vue = { "prettierd" },
      ["yaml.ansible"] = { "ansible-lint", "yamlfmt" },
      ["yaml.docker"] = { "prettierd", "yamlfmt" },
      ["yaml.kubernetes"] = { "kubectl_yaml", "yamlfmt" },
      yaml = { "prettierd", "yamlfmt" },
      yml = { "prettierd", "yamlfmt" },
    },

    default_format_opts = opts.default_format_opts or {
      lsp_format = "fallback",
    },

    format_on_save = opts.format_on_save or {
      lsp_format = "fallback",
      timeout_ms = 500,
      exclude = { "spell", "codespell" },
    },

    format_after_save = opts.format_after_save or {
      lsp_format = "fallback",
    },

    log_level = opts.log_level or vim.log.levels.ERROR,
    notify_on_error = opts.notify_on_error ~= false,
    notify_no_formatters = opts.notify_no_formatters ~= false,

    formatters = opts.formatters or {
      black = {
        prepend_args = { "--line-length", "88" },
      },
      cargo_leptos_fmt = {
        command = "cargo",
        args = { "leptosfmt" },
        stdin = false,
        condition = function(ctx)
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
        prepend_args = function(_self, ctx)
          vim.schedule(function()
            vim.notify(
              "Formatting with stylua: " .. (ctx.filename or "unknown"),
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
  }
end

return M
