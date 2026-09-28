-- /qompassai/Diver/lua/ai/agx/health.lua
-- Qompass AI agx checkhealth (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Run with :checkhealth ai.agx

local M = {}

function M.check()
    local health = vim.health

    health.start('agx: trace inspector')
    if vim.fn.executable('agx') == 1 then
        health.ok('agx found (:Agx opens the session browser)')
    else
        health.warn('agx not found on PATH; :Agx will refuse (paru -S aur/agx)')
    end

    health.start('agx: session sources')
    local found_any = false
    for _, dir in ipairs({ '.claude', '.codex', '.gemini' }) do
        local home = vim.fn.expand('~/' .. dir)
        if vim.fn.isdirectory(home) == 1 then
            health.ok(dir .. '/ exists — agx can browse its sessions')
            found_any = true
        end
    end
    if not found_any then
        health.info('no ~/.claude, ~/.codex, or ~/.gemini dirs yet; nothing to inspect')
    end
end

return M
