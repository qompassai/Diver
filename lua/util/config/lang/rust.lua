-- ~/nvim/lua/config/lang/rust.lua
local M = {}
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = true,
  severity_sort = true,
})
M.rust_editions = {
  ["2021"] = "2021",
  ["2024"] = "2024",
}
M.rust_toolchains = {
  stable = "stable",
  nightly = "nightly",
  beta = "beta",
}
M.default_edition = "2021"
M.default_toolchain = "stable"
function M.set_rust_edition(edition)
  if M.rust_editions[edition] then
    M.current_edition = edition
    vim.notify("Rust edition set to " .. edition, vim.log.levels.INFO)
    vim.cmd("LspRestart")
  else
    vim.notify("Invalid Rust edition: " .. tostring(edition), vim.log.levels.ERROR)
  end
end
function M.set_rust_toolchain(toolchain)
  if M.rust_toolchains[toolchain] then
    M.current_toolchain = toolchain
    vim.notify("Rust toolchain set to " .. toolchain, vim.log.levels.INFO)
    vim.cmd("LspRestart")
  else
    vim.notify("Invalid Rust toolchain: " .. tostring(toolchain), vim.log.levels.ERROR)
  end
end
function M.refresh_diagnostics()
  vim.cmd("write")
  vim.diagnostic.disable()
  vim.defer_fn(function()
    vim.diagnostic.enable()
  end, 200)
end
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
  vim.lsp.set_log_level("INFO")
  M.current_edition = M.current_edition or M.default_edition
  M.current_toolchain = M.current_toolchain or M.default_toolchain
  if capabilities then
    capabilities.textDocument = capabilities.textDocument or {}
    capabilities.textDocument.codeLens = {
      dynamicRegistration = true
    }
    capabilities.textDocument.synchronization = {
      dynamicRegistration = true,
      willSave = true,
      willSaveWaitUntil = true,
      didSave = true
    }
    capabilities.textDocument.semanticTokens = {
      dynamicRegistration = true,
      tokenTypes = {
        "namespace", "type", "class", "enum", "interface",
        "struct", "typeParameter", "parameter", "variable", "property",
        "enumMember", "event", "function", "method", "macro",
        "keyword", "modifier", "comment", "string", "number",
        "regexp", "operator", "decorator"
      },
      tokenModifiers = {
        "declaration", "definition", "readonly", "static",
        "deprecated", "abstract", "async", "modification",
        "documentation", "defaultLibrary"
      },
      formats = { "relative" },
      requests = {
        range = true,
        full = {
          delta = true
        }
      }
    }
    capabilities.workspace = capabilities.workspace or {}
    capabilities.workspace.didChangeWatchedFiles = {
      dynamicRegistration = true
    }
  vim.g.rustaceanvim = {
    server = {
      on_attach = function(client, bufnr)
        if client.server_capabilities.workspace then
          client.server_capabilities.workspace.didChangeWatchedFiles = { 
            dynamicRegistration = true 
          }
        else
          client.server_capabilities.workspace = {
            didChangeWatchedFiles = { dynamicRegistration = true }
          }
        end
        vim.api.nvim_buf_create_user_command(bufnr, "RustSetEdition", function(opts)
          M.set_rust_edition(opts.args)
        end, {
          nargs = 1,
          complete = function()
            return vim.tbl_keys(M.rust_editions)
          end,
        })
        vim.api.nvim_buf_create_user_command(bufnr, "RustSetToolchain", function(opts)
          M.set_rust_toolchain(opts.args)
        end, {
          nargs = 1,
          complete = function()
            return vim.tbl_keys(M.rust_toolchains)
          end,
        })
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
            allFeatures = true,
            loadOutDirsFromCheck = true,
            runBuildScripts = true,
          },
          checkOnSave = true,
          check = {
            allFeatures = true,
            command = "clippy",
            extraArgs = { "--target-dir=target/analyzer" },
          },
          diagnostics = {
            enable = true,
            experimental = { enable = true },
            disabled = { "unresolved-proc-macro", "macro-error" },
          },
          files = {
            excludeDirs = { ".direnv", ".git", "target", "node_modules", "tests/generated", ".zig-cache" },
            watcher = "client",
          },
          procMacro = {
            enable = true,
            attributes = { enable = true },
          },
          inlayHints = {
            typeHints = true,
            parameterHints = true,
            chainingHints = true,
            closingBraceHints = true,
          },
          rustc = {
            source = M.current_toolchain,
            edition = M.current_edition,
          },
        },
      },
    },
  }
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "rust-analyzer" then
        local nvim_version = vim.version()
        if nvim_version and (nvim_version.major > 0 or nvim_version.minor >= 10) then
          vim.lsp.inlay_hint.enable(true, args.buf)
        else
          vim.lsp.inlay_hint.enable(args.buf, true)
        end
      end
    end,
  })
end
function M.rust(on_attach, capabilities)
  M.rust_crates()
  M.rust_nls()
  M.rust_dap()
  M.rust_lsp(on_attach, capabilities)
  vim.api.nvim_create_user_command("RustEdition", function(opts)
    M.set_rust_edition(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_editions)
    end,
  })
  vim.api.nvim_create_user_command("RustToolchain", function(opts)
    M.set_rust_toolchain(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return vim.tbl_keys(M.rust_toolchains)
    end,
  })
  vim.keymap.set("n", "<leader>rd", M.refresh_diagnostics, { desc = "Refresh Diagnostics" })
  vim.keymap.set("n", "<leader>re", function() vim.ui.select(vim.tbl_keys(M.rust_editions), { prompt = "Select Rust Edition" }, M.set_rust_edition) end, { desc = "Select Rust Edition" })
  vim.keymap.set("n", "<leader>rt", function() vim.ui.select(vim.tbl_keys(M.rust_toolchains), { prompt = "Select Rust Toolchain" }, M.set_rust_toolchain) end, { desc = "Select Rust Toolchain" })
end
end
return M
