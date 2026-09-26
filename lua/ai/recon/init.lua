-- /qompassai/Diver/lua/ai/recon/init.lua
-- Recon subsystem: skills, CLI tools, gate, and bridge wiring.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this is the front door of the pentest tooling.
-- setup() scans the skill library once, registers the :Recon*
-- commands, and configures the execution gate. Nothing runs and
-- nothing listens until you ask it to.
---@module 'ai.recon'

local M = {}

local did_setup = false

---@class ReconSetupOpts
---@field skills_dir? string Where the SKILL.md library lives
---@field auto_authorize? boolean Skip confirmation prompts (default true)

---Idempotent setup.
---@param opts? ReconSetupOpts
function M.setup(opts)
    opts = opts or {}
    require('ai.recon.gate').setup({ auto_authorize = opts.auto_authorize })
    require('ai.mcp.skills').setup({ skills_dir = opts.skills_dir })
    local loaded, errors = require('ai.mcp.skills').scan()
    for _, err in ipairs(errors) do
        vim.notify('[recon] skill load warning: ' .. err, vim.log.levels.WARN)
    end
    if not did_setup then
        require('ai.recon.commands').register()
        did_setup = true
    end
    return { skills = loaded, errors = #errors }
end

return M
