local M = {}
local crates_module = nil
function M.setup_dap()
  local dap = require("dap")
  dap.adapters.lldb = {
    type = "executable",
    command = "/usr/bin/lldb",
    name = "lldb",
  }
  dap.configurations.rust = {
    {
      name = "Launch",
      type = "lldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: " .. vim.fn.getcwd() .. "/")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
  }
  local dapui = require("dapui")
  dapui.setup()
  dap.listeners.before.attach.dapui_config = function()
    dapui.open()
  end
  dap.listeners.before.launch.dapui_config = function()
    dapui.open()
  end
  dap.listeners.after.event_terminated.dapui_config = function()
    dapui.close()
  end
  dap.listeners.after.event_exited.dapui_config = function()
    dapui.close()
  end
  local jit = require("jit")
  local sysname = (jit and jit.os) or "Linux"
  local mason_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
  local codelldb_path = mason_path .. "adapter/codelldb"
  if sysname == "OSX" then
  elseif sysname == "Windows" then
    dap.adapters.lldb = {
      type = "executable",
      command = codelldb_path,
      name = "lldb",
    }
    dap.configurations.rust = {
      {
        name = "Launch",
        type = "lldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
    }
  end
  --None-LS--
function M.setup_none_ls_sources()
  local null_ls = require("null-ls")
  local rust_sources = {
    null_ls.builtins.formatting.dxfmt.with({
      ft = { "rust" },
      cmd = "dx",
      extra_args = { "fmt", "--file", "$FILENAME" }
    }),
    null_ls.builtins.diagnostics.ltrs.with({
            method = null_ls.methods.DIAGNOSTICS,
            ft = { "text", "markdown", "markdown" },
            cmd = "ltrs",
            extra_args = { "check", "-m", "-r", "--text", "$TEXT" }
          }),
    null_ls.builtins.formatting.leptosfmt.with({
      method = null_ls.methods.FORMATTING,
      ft = { "rust" },
      cmd = "leptosfmt",
      extra_args = { "--quiet", "--stdin" }
    }),
  }
    return rust_sources
  end
  -- LSP config --
  function M.setup_lsp(on_attach, capabilities)
    vim.g.rustaceanvim = {
      server = {
        on_attach = function(client, bufnr)
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
          print("Attached client:", client.name)
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
              features = "all",
              target = "nil",
            },
            checkOnSave = { command = "clippy" },
            diagnostics = {
              enable = true,
              experimental = { enable = true },
              disabled = { "unresolved-proc-macro", "macro-error" },
            },
            files = {
              excludeDirs = {
                ".direnv",
                ".git",
                "target",
                "node_modules",
              },
            },
            procMacro = {
              enable = true,
              attributes = {
                enable = true,
              },
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
-- Crates.nvim setup
function M.setup_crates()
  crates_module = require("crates")
  crates_module.setup({
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
      vim.defer_fn(function()
        crates_module.show()
      end, 300)
    end,
  })
end

function M.show()
  if not crates_module then return end
  crates_module.show()
end
function M.hide()
  if not crates_module then return end
  crates_module.hide()
end
function M.toggle()
  if not crates_module then return end
  crates_module.toggle()
end
function M.update(buf)
  if not crates_module then return end
  crates_module.update(buf)
end
function M.upgrade_crate(alt)
  if not crates_module then return end
  crates_module.upgrade_crate(alt)
end
function M.upgrade_all_crates(alt)
  if not crates_module then return end
  vim.notify("Upgrading all crates...", vim.log.levels.INFO)
  crates_module.upgrade_all_crates(alt)
end
function M.open_homepage()
  if not crates_module then return end
  crates_module.open_homepage()
end
function M.open_documentation()
  if not crates_module then return end
  crates_module.open_documentation()
end
function M.open_crates_io()
  if not crates_module then return end
  crates_module.open_crates_io()
end
function M.show_popup()
  if not crates_module then return end
  crates_module.show_popup()
end
-- Leptos LSP
function M.setup_leptos(on_attach, capabilities)
   vim.lsp.config["rust_analyzer"] = {
    cmd = { "rust-analyzer" },
    capabilities = capabilities,
    on_attach = on_attach,
    filetypes = { "rust" },
    root_dir = vim.fs.dirname(vim.fs.find({"Cargo.toml", ".git"}, { upward = true })[1]),
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = {
          allFeatures = true,
          command = "clippy"
        },
        diagnostics = {
          enable = true,
        },
        procMacro = {
          enable = true,
          ignored = {
            ["leptos-macro"] = { "server" }
        }
        },
        cargo = {
          allFeatures = true,
          features = { "ssr" }
        },
        rustfmt = {
          overrideCommand = { "leptosfmt", "--stdin", "--rustfmt" }
        }
      }
    },
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = true
    end
  }
  vim.lsp.config["leptos_ls"] = {
    cmd = { "leptosfmt", "lsp" },
    filetypes = { "rust" },
    root_dir = vim.fs.dirname(vim.fs.find({"Cargo.toml", ".git"}, { upward = true })[1]),
  }
  vim.lsp.enable("rust_analyzer")
  vim.lsp.enable("leptos_ls")
end

function M.setup_all(on_attach, capabilities)
  M.setup_crates()
  M.setup_none_ls_sources()
  M.setup_dap()
  M.setup_leptos(on_attach, capabilities)
  M.setup_lsp(on_attach, capabilities)
end
end
return M
