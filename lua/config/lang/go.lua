-- /qompassai/Diver/lua/config/lang/go.lua
-- Qompass AI Diver Go Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local function go_dap()
  return require("dap")
end
local function run_cached_gvm(cmd)
  local handle = io.popen("bash -c 'source ~/.gvm/scripts/gvm && " .. cmd .. "'")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result and vim.trim(result) or nil
end
local function get_go_bin()
  return run_cached_gvm("which go") or "go"
end
local function get_gopath()
  return run_cached_gvm("go env GOPATH") or os.getenv("GOPATH") or ""
end
local function get_go_version()
  return run_cached_gvm("go version") or ""
end
function M.go_autocmds()
  vim.api.nvim_create_user_command("GoEnvInfo", function()
    for label, value in pairs({
      ["Go Binary"] = get_go_bin(),
      ["Go Version"] = get_go_version(),
      ["GOPATH"] = get_gopath(),
    }) do
      vim.notify_once(string.format("%s: %s", label, value), vim.log.levels.INFO)
    end
  end, {})
end
function M.go_conform()
  return {
    formatters_by_ft = {
      ["go"] = {
        "goimports",
        "gofumpt",
      },
    },
    formatters = {
      goimports = { command = "goimports", args = { "-srcdir", "$DIRNAME" } },
      gofumpt = { command = "gofumpt", args = { "$FILENAME" } },
    },
  }
end
function M.go_dap()
  function run_cached_gvm(cmd)
    local handle = io.popen("bash -c 'source ~/.gvm/scripts/gvm && " .. cmd .. "'")
    if not handle then
      return nil
    end
    local result = handle:read("*a")
    handle:close()
    return result and vim.trim(result) or nil
  end
  local function get_dlv_bin()
    return run_cached_gvm("which dlv") or "dlv"
  end
  local dap_go_ok, dap_go = pcall(require, "dap-go")
  if dap_go_ok then
    dap_go.setup({
      delve = {
        path = get_dlv_bin(),
        initialize_timeout_sec = 20,
        port = "${port}",
      },
    })
  end
  local dapui_ok, dapui = pcall(require, "dapui")
  if dapui_ok then
    dapui.setup()
    local dap = go_dap()
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
  end
end
function M.nls(opts)
  opts = opts or {}
  local nlsb = require("null-ls").builtins
  local sources = {
    nlsb.code_actions.gomodifytags.with({ ft = { "go" } }),
    nlsb.code_actions.refactoring.with({ ft = { "go" } }),
    nlsb.diagnostics.golangci_lint.with({ ft = { "go" } }),
    nlsb.diagnostics.revive.with({ ft = { "go" } }),
    nlsb.diagnostics.staticcheck.with({ ft = { "go" } }),
    nlsb.formatting.goimports.with({ ft = { "go" } }),
    nlsb.formatting.goimports_reviser.with({ ft = { "go" } }),
    nlsb.formatting.gofmt.with({ ft = { "go" } }),
    nlsb.formatting.gofumpt.with({ ft = { "go" } }),
    nlsb.formatting.golines.with({ ft = { "go" } }),
  }
  return sources
end

function M.go_cfg(opts)
  opts = opts or {}
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local on_attach = function(_, _) end
  M.go_lsp(on_attach, capabilities)
  local null_ls_ok, null_ls = pcall(require, "null-ls")
  if null_ls_ok then
    null_ls.register({
      sources = M.nls(opts),
    })
  end
  local conform_ok, conform = pcall(require, "conform")
  if conform_ok then
    conform.setup(M.go_conform())
  end
end

return M
