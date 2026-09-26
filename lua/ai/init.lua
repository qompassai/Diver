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
--               an inbound server. a2a/orchestrator.lua fans one task out
--               across SDK drivers by language and aggregates the results.
--   ai/rose/    rose.nvim fold-in (native, no plugins): chat, agent loop,
--               Ollama, MCP helpers, validation, and all 10 cloud
--               providers. Optional generation backend for ai/builder.
--   ai/mcp/     MCP server manager (mcphub-like, no plugins): registry,
--               stdio client, tool inspection, menu UI, and server
--               discovery via SearXNG (primary) / Brave (fallback).
--   ai/webmcp/  Firenvim-style bridge without the plugin: a localhost
--               WebSocket server exposing named RPC endpoints (SCIP,
--               recon skills, CLI tools) with WebMCP safety annotations,
--               plus a dashboard page that registers them via
--               document.modelContext.registerTool().
--   ai/recon/   Authorized-engagement pentest tooling: SKILL.md skill
--               library loader (ai.mcp.skills), bounded CLI tool
--               wrappers, output parsers, execution gate (auto-
--               authorized, always audit-logged), and :Recon* commands.
--   ai/security/
--               Anti-malware / anti-poisoning: content scanner run over
--               files before they enter AI context, plus the tool-call
--               confirmation policy MCP/A2A dispatch consults.
--   ai/builder/ Interactive full-application builder: option menus plus
--               free write-in, plan -> generate -> validate -> review with
--               confirmation at every stage, writes only after approval.
--   ai/media/   Audio (TTS) / image / video generation: local-first
--               backend registry with honest availability reporting.
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
    require('ai.a2a.orchestrator').setup()
    require('ai.rose').setup()
    require('ai.mcp').setup()
    require('ai.security').setup()
    require('ai.builder').setup()
    require('ai.media').setup()
    require('ai.herd').setup()
    require('ai.debugbridge').setup()
    require('ai.dataaccess').setup()
    require('ai.recon').setup()
end

return M
