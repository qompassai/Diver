-- /qompassai/Diver/lua/config/core/trouble.lua
-- Qompass AI Diver Trouble Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

---@class TroubleOptions
---@field position? "top" | "bottom" | "left" | "right"
---@field height? integer
---@field use_diagnostic_signs? boolean
---@field auto_open? boolean
---@field auto_close? boolean
---@field auto_preview? boolean
---@field mode? "workspace_diagnostics" | "document_diagnostics"

---@param opts? TroubleOptions
---@return TroubleOptions
return function(opts)
  opts = opts or {}
  return vim.tbl_deep_extend("force", {
    position = "bottom",
    height = 10,
    auto_open = true,
    auto_close = true,
    use_diagnostic_signs = true,
  }, opts)
end
