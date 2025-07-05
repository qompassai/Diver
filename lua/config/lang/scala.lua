-- /qompassai/Diver/lua/config/scala.lua
-- Qompass AI Diver Scala Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}

function M.setup(user_opts)
  local opts   = user_opts or {}
  local scala  = M.scala_cfg(opts)
  local cmp_mod = vim.g.use_blink_cmp and "blink.cmp" or "cmp"
  require(cmp_mod).setup(scala.cmp)
  scala.lsp({
    on_attach    = require("config.core.lspconfig").on_attach,
    capabilities = require("config.core.lspconfig").lsp_capabilities(),
  })
  local ok_nls, null_ls = pcall(require, "null-ls")
  if ok_nls then null_ls.register(scala.nls) end
  local ok_con, conform = pcall(require, "conform")
  if ok_con then conform.setup(scala.conform) end
  local ok_test, neotest = pcall(require, "neotest")
  if ok_test then neotest.setup(scala.test) end
  local ok_dapui, dapui = pcall(require, "dapui")
  if ok_dapui then dapui.setup() end
end
return M
