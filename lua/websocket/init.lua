-- /qompassai/Diver/lua/websocket/init.lua
-- Native WebSocket for Neovim (no FFI, no external plugin).
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this is the front door of the native WebSocket
-- modules. Call setup() once, then use websocket.client and
-- websocket.server. The wire protocol (RFC 6455) runs over
-- Neovim's built-in networking, so it works anywhere Neovim runs.
---@module 'websocket'

local M = {}

---@class WebsocketSetupOpts
---@field random_seed? integer seed for math.random (handshake keys)

---Initialize the websocket modules. Safe to call more than once.
---@param opts? WebsocketSetupOpts
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    if opts.random_seed ~= nil then
        assert(type(opts.random_seed) == 'number', 'random_seed must be a number')
        math.randomseed(opts.random_seed)
    else
        math.randomseed(vim.uv.hrtime())
    end
    M._setup_done = true
end

return M
