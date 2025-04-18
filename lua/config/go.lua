-- ~/.config/nvim/lua/config/go.lua
local dap = require("dap")
local dap_go = require("dap-go")
local dapui = require("dapui")
local lspconfig = require("lspconfig")
local null_ls = require("null-ls")

local M = {}

function M.null_ls_sources()
  local formatting = null_ls.builtins.formatting
  local diagnostics = null_ls.builtins.diagnostics
  local code_actions = null_ls.builtins.code_actions
  return {
    formatting.asmfmt.with({ filetypes = { "asm" } }),
    formatting.goimports.with({ filetypes = { "go" }, extra_args = { "-srcdir", "$DIRNAME" } }),
    formatting.goimports_reviser.with({ filetypes = { "go" }, extra_args = { "$FILENAME" } }),
    formatting.gofmt.with({ filetypes = { "go" } }),
    formatting.gofumpt.with({ filetypes = { "go" } }),
    formatting.golines.with({ filetypes = { "go" } }),
    code_actions.gomodifytags,
    diagnostics.golangci_lint.with({
      filetypes = { "go" },
      extra_args = { "run", "--fix=false", "--out-format=json" },
    }),
    diagnostics.revive.with({ filetypes = { "go" }, extra_args = { "-formatter", "json", "./..." } }),
    diagnostics.staticcheck.with({ filetypes = { "go" }, extra_args = { "-f", "json", "./..." } }),
    diagnostics.vacuum.with({
      filetypes = { "yaml", "json" },
      args = { "report", "--stdin", "--stdout", "--format", "json" },
      to_stdin = true,
      format = "json",
    }),
    diagnostics.verilator.with({
      filetypes = { "verilog", "systemverilog" },
      extra_args = { "-lint-only", "-Wno-fatal", "$FILENAME" },
    }),
  }
end

-- GVM environment support
local function run_in_gvm(cmd)
  local handle = io.popen("bash -c 'source ~/.gvm/scripts/gvm && " .. cmd .. "'")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result and vim.trim(result) or nil
end

local gvm_env = run_in_gvm("env") or ""
local function run_cached_gvm(cmd)
  local handle = io.popen("bash -c '" .. gvm_env .. " && " .. cmd .. "'")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result and vim.trim(result) or nil
end

M.get_go_bin = function()
  return run_cached_gvm("which go") or "go"
end
M.get_dlv_bin = function()
  return run_cached_gvm("which dlv") or "dlv"
end
M.get_gopath = function()
  return run_cached_gvm("go env GOPATH") or os.getenv("GOPATH") or ""
end
M.get_go_version = function()
  return run_cached_gvm("go version") or ""
end

function M.setup(on_attach, capabilities)
  if not lspconfig.gopls then
    vim.notify("gopls LSP is not available.", vim.log.levels.ERROR)
    return
  end

  lspconfig.gopls.setup({
    cmd = { M.get_go_bin() },
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      if type(on_attach) == "function" then
        on_attach(client, bufnr)
      end
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          if vim.bo.filetype == "go" then
            vim.lsp.buf.format({ async = false })
          end
        end,
      })
    end,
    settings = {
      gopls = {
        buildFlags = { "-tags=integration,e2e,cgo" },
        staticcheck = true,
        gofumpt = true,
        usePlaceholders = true,
        completeUnimported = true,
        experimentalWorkspaceModule = true,
        analyses = {
          unusedparams = true,
          shadow = true,
          fieldalignment = true,
          nilness = true,
        },
        env = { GOPATH = M.get_gopath() },
      },
    },
    flags = { debounce_text_changes = 150 },
    init_options = { buildFlags = { "-tags=cgo" } },
  })

  dap_go.setup({
    delve = {
      path = M.get_dlv_bin(),
      initialize_timeout_sec = 20,
      port = "${port}",
    },
  })

  dapui.setup()
  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  if vim.fn.executable("go") == 0 then
    vim.notify("Go binary not found in PATH", vim.log.levels.WARN)
  end

  vim.api.nvim_create_user_command("GoEnvInfo", function()
    for label, value in pairs({
      ["Go Binary"] = M.get_go_bin(),
      ["Go Version"] = M.get_go_version(),
      ["GOPATH"] = M.get_gopath(),
      ["Delve Binary"] = M.get_dlv_bin(),
    }) do
      vim.notify_once(string.format("%s: %s", label, value), vim.log.levels.INFO)
    end
  end, {})

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("GoFmt", { clear = true }),
    pattern = "*.go",
    callback = function()
      vim.lsp.buf.format({ async = false })
    end,
  })
end

return M
