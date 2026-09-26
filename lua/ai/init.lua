-- /qompassai/Diver/lua/ai/init.lua
-- Qompass AI Agent Protocols Entry Point (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Top-level entry for Diver's agent-protocol integrations. Wires the
-- subprotocol modules into one setup() call. Nothing in this file does
-- I/O at require-time; each submodule spawns its sessions lazily and
-- owns its own teardown on VimLeavePre.
--
-- Layout:
--   ai/acp/     Zed's Agent Client Protocol: Neovim as the client that
--               drives coding-agent subprocesses over stdio.
--   ai/a2a/     Agent2Agent: Neovim as the operator console -- discover
--               agents, dispatch tasks, supervise them, aggregate results.
--               Flow owns server-side orchestration; this side never runs
--               an inbound server.
--   ai/context.lua
--               Agent Context Protocol: the markdown knowledge convention
--               (agent/commands, agent/patterns, ...) an agent reads.
--               No wire protocol, no RPC, no process.

local M = {}

---@param opts? table Reserved for future options; currently unused.
function M.setup(opts)
    assert(opts == nil or type(opts) == 'table', 'ai.setup expects a table or nil')

    require('ai.acp').setup()
    require('ai.a2a').setup()
end

return M
