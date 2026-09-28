-- /qompassai/diver/lua/ai/harness/health.lua
-- Qompass AI Agent Harness: runtime health report (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Honest capability reporting: every field says what was actually probed.
-- Unavailable adapters, missing storage, and absent sandbox profiles are
-- reported as facts, never papered over.

local adapter = require('ai.harness.adapter')
local registry = require('ai.harness.registry')
local sandbox = require('ai.harness.sandbox')

local M = {}

---Probe the harness runtime, registered adapters, storage, and sandbox.
---@param ctx? table {registry?: table, store?: table}
---@return table report
function M.check(ctx)
    ctx = ctx or {}
    local report = {
        runtime = {
            lua_version = _VERSION,
            jit = jit ~= nil,
            has_vim = vim ~= nil,
            has_uv = vim ~= nil and vim.uv ~= nil,
        },
        adapters = {},
        storage = { runs_stored = 0 },
        sandbox = { profiles = {} },
    }
    local reg = ctx.registry
    if reg ~= nil then
        for _, name in ipairs(registry.list_adapters(reg)) do
            local adapter_mod = registry.get_adapter(reg, name)
            local caps, err = adapter.probe(adapter_mod)
            if caps ~= nil then
                report.adapters[name] = {
                    available = caps.available,
                    wired_start = caps.wired_start == true,
                    notes = caps.notes,
                }
            else
                report.adapters[name] = { available = false, error = tostring(err) }
            end
        end
    end
    if ctx.store ~= nil and type(ctx.store.runs) == 'table' then
        local count = 0
        for _ in pairs(ctx.store.runs) do
            count = count + 1
        end
        report.storage.runs_stored = count
    end
    for name in pairs(sandbox.PROFILES) do
        report.sandbox.profiles[#report.sandbox.profiles + 1] = name
    end
    table.sort(report.sandbox.profiles)
    return report
end

return M
