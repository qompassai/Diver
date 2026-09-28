-- /qompassai/Diver/lua/dev/bootdev/health.lua
-- Qompass AI bootdev-local checkhealth (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Run with :checkhealth dev.bootdev

local M = {}

function M.check()
    local health = vim.health

    health.start('bootdev: lesson runner')
    if vim.fn.executable('bootdev-local') == 1 then
        health.ok('bootdev-local found (:Bootdev <lesson-URL> opens a lesson)')
    else
        health.warn(
            'bootdev-local not found on PATH; :Bootdev will refuse (paru -S aur/bootdev-local)'
        )
    end
end

return M
