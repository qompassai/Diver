-- /qompassai/Diver/lua/ai/mcp/init.lua
-- Qompass AI MCP Manager Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Native MCP (Model Context Protocol) server manager, mcphub.nvim-like,
-- zero plugins. Requiring this module has no side effects; setup() is
-- idempotent and spawns nothing -- server processes start lazily on first
-- use and are torn down on VimLeavePre.
--
-- Layout:
--   registry.lua   Server registry CRUD, JSON persistence (atomic
--                  tmp+rename), entry validation and risk flags.
--   client.lua     MCP stdio JSON-RPC client: newline-delimited framing,
--                  request/response matching with timeouts, initialize
--                  handshake, one session per server. Uses ai.rose.mcp
--                  opportunistically when it exposes new_stdio_client.
--   tools.lua      tools/list, schema inspection, and tool calls -- the
--                  call path always passes an explicit confirmation
--                  (ai.security when present, vim.ui.select otherwise).
--   ui.lua         Floating-window browser over servers and tools, in the
--                  style of ai.a2a.ui.
--   discovery.lua  MCP server search: SearXNG first (reusing
--                  config.nav.searxng's M.parse), Brave Search API only
--                  when SearXNG is unconfigured. Install writes a registry
--                  entry only after typed confirmation of the full argv.
--   commands.lua   Mcp* user commands. Requiring it registers them.
--
-- NOTE: ai/init.lua (the coordinator) must require('ai.mcp').setup() --
-- that wiring is intentionally left to the coordinator, not done here.

local M = {}

local setup_done = false

function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    require('ai.mcp.commands')
    local group = vim.api.nvim_create_augroup('diver-mcp', { clear = true })
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = group,
        callback = function()
            require('ai.mcp.client').stop_all()
        end,
    })
end

return M
