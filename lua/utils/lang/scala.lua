-- /qompassai/Diver/lua/utils/lang/scala.lua
-- Qompass AI Diver Scala Lang Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------------------
local U = {}
local function has(mod) return pcall(require, mod) end

function U.scala_cmp()
  local caps = vim.lsp.protocol.make_client_capabilities()
  if has("cmp_nvim_lsp") then
    caps = require("cmp_nvim_lsp").default_capabilities(caps)
  end
  return caps
end

function U.scala_metals()
  return {
    showImplicitArguments    = true,
    showInferredType         = true,
    superMethodLensesEnabled = true,
    excludedPackages         = { "akka.*" },
    serverVersion            = "2.1.24",
  }
end

function U.scala_lsp(on_attach, capabilities)
  local metals      = require("metals")
  local cfg         = metals.bare_config()
  cfg.on_attach     = on_attach
  cfg.capabilities  = capabilities
  cfg.init_options  = { statusBarProvider = "on" }
  cfg.settings      = U.scala_metals()
  cfg.serverVersion = "1.4.10"

  return cfg
end

function U.scala_dap()
  if not pcall(require, "dap") then return end
  local dap = require("dap")
  dap.configurations.scala = {
    {
      type    = "scala",
      request = "launch",
      name    = "Run / Test file",
      metals  = { runType = "runOrTestFile" },
    },
    {
      type    = "scala",
      request = "launch",
      name    = "Test target",
      metals  = { runType = "testTarget" },
    },
  }
end

return U
