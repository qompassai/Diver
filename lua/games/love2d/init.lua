-- /qompassai/Diver/lua/games/love2d/init.lua
-- Qompass AI LÖVE2D Platform Core
-- Centralized LÖVE2D platform core: pinned 11.5 runtime management,
-- deterministic .love packaging, per-OS release fusion, a curated library
-- catalog, the dev loop (run / hot-reload / debug console / profiler), an
-- engine adapter contract, and health checks.
--
-- Engine wiring into games/init.lua happens in a later integration pass;
-- see the track report for the snippet.
local M = {}
M.actions = require('games.love2d.actions')
M.adapters = require('games.love2d.adapters')
M.commands = require('games.love2d.commands')

M.config = require('games.love2d.config')
M.dev = require('games.love2d.dev')
M.health = require('games.love2d.health')
M.libs = require('games.love2d.libs')
M.package = require('games.love2d.package')
M.release = require('games.love2d.release')
M.versions = require('games.love2d.versions')

function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
