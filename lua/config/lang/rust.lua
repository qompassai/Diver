-- ~/nvim/lua/config/lang/rust.lua

local M = {}
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})
function M.rust_dap()
  local dap = require("dap")
  local dapui = require("dapui")
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = "/usr/bin/codelldb",
      args = { "--port", "${port}" },
    },
  }
  dap.configurations.rust = {
    {
      name = "Launch",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: " .. vim.fn.getcwd() .. "/")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }
  dap.listeners.after.event_exited.dapui_config = function()
    dapui.close()
  end
end
-- null-ls configuration for Rust formatting/diagnostics
function M.rust_nls()
  local null_ls = require("null-ls")
  return {
    null_ls.builtins.formatting.dxfmt.with({
      ft = { "rust" },
      command = "dx",
      extra_args = { "fmt", "--file", "$FILENAME" },
    }),
    null_ls.builtins.diagnostics.ltrs.with({
      method = null_ls.methods.DIAGNOSTICS,
      ft = { "text", "markdown" },
      command = "ltrs",
      extra_args = { "check", "-m", "-r", "--text", "$TEXT" },
    }),
    null_ls.builtins.formatting.leptosfmt.with({
      method = null_ls.methods.FORMATTING,
      ft = { "rust" },
      command = "leptosfmt",
      extra_args = { "--quiet", "--stdin" },
    }),
  }
end

-- Crates.nvim integration
function M.rust_crates()
  local crates = require("crates")
  crates.setup({
    smart_insert = true,
    insert_closing_quote = true,
    autoload = true,
    autoupdate = true,
    autoupdate_throttle = 250,
    loading_indicator = true,
    date_format = "%Y-%m-%d",
    thousands_separator = ".",
    notification_title = "crates.nvim",
    popup = {
      autofocus = false,
      hide_on_select = false,
      border = "none",
      show_version_date = true,
    },
    lsp = {
      enabled = true,
      name = "crates.nvim",
      actions = true,
      completion = true,
    },
  })
  vim.api.nvim_create_autocmd("BufRead", {
    pattern = "Cargo.toml",
    callback = function()
      vim.defer_fn(crates.show, 300)
    end,
  })
end
function M.rust_lsp(on_attach, capabilities)
  vim.g.rustaceanvim = {
    server = {
      on_attach = function(client, bufnr)
        vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
        if type(on_attach) == "function" then
          on_attach(client, bufnr)
        end
      end,
      capabilities = capabilities,
      settings = {
        ["rust-analyzer"] = {
          assist = {
            expressionFillDefault = "default",
            importGranularity = "module",
            importPrefix = "self",
          },
          cargo = {
            allFeatures = false,
            loadOutDirsFromCheck = true,
            runBuildScripts = true,
            features = "default",
          },
          checkOnSave = true,
          check = {
            allFeatures = true,
            command = "clippy",
          },
          diagnostics = {
            enable = true,
            experimental = { enable = true },
            disabled = { "unresolved-proc-macro", "macro-error" },
          },
          files = {
            excludeDirs = { ".direnv", ".git", "target", "node_modules","tests/generated", ".zig-cache" },
          },
          procMacro = {
            enable = false,
            attributes = { enable = true },
          },
          inlayHints = {
            typeHints = true,
            parameterHints = true,
            chainingHints = true,
            closingBraceHints = true,
          },
        },
      },
    },
  }
end
function M.rust(on_attach, capabilities)
  M.rust_crates()
  M.rust_nls()
  M.rust_dap()
  M.rust_lsp(on_attach, capabilities)
end
return M
