-- /qompassai/Diver/lua/config/lang/neoconf.lua
-- Qompass AI Diver Neoconf Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}

---@param opts? table
---@return table
function M.opts(opts)
  opts = opts or {}
  return {
    local_settings  = opts.local_settings or '.neoconf.json',
    global_settings = opts.global_settings or 'neoconf.json',
    import          = opts.import or { vscode = true, coc = true, nlsp = true },
    live_reload     = opts.live_reload ~= true,
    filetype_jsonc  = opts.filetype_jsonc ~= false,
    plugins         = opts.plugins or {
      lspconfig = { enabled = true },
      jsonls    = { enabled = true, configured_servers_only = true },
      lua_ls    = { enabled_for_neovim_config = true, enabled = true },
    },
  }
end

return M
