-- /qompassai/Diver/lua/config/scala.lua
-- Qompass AI Diver Scala Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local U = require('utils.lang.scala')

local M = {}

function M.scala_cfg()
    U.scala_dap()
end

---@param on_attach fun(client,bufnr)
---@param capabilities table
function M.scala_lsp(on_attach, capabilities)
    return U.scala_lsp(on_attach, capabilities or U.scala_cmp())
end
return M
