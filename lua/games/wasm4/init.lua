-- /qompassai/Diver/lua/games/wasm4/init.lua
-- Qompass AI WASM-4 Native Dev Loop
--- Native WASM-4 dev loop: scaffold, build, run, watch, and bundle
--- carts through the w4 CLI (v2.7.1) without leaving Neovim.
---
--- The edit-build loop is `w4 watch` (rebuild + web-runtime refresh),
--- so unlike games.tic80 this module needs no BufWritePost machinery:
--- the CLI owns the loop. The web runtime serves on port 4444 with a
--- QR code, which is also the phone route; `w4 bundle --html` emits
--- the single self-contained page used the same way.
---
--- Rust is the default language: scaffolding applies the proven
--- `--allow-undefined` link fix to the generated `.cargo/config.toml`
--- (current rust-lld refuses the console API's env imports otherwise).
---@module 'games.wasm4'

local actions = require('games.wasm4.actions')
local commands = require('games.wasm4.commands')
local config = require('games.wasm4.config')
local util = require('games.wasm4.util')

local M = {}
M.actions = actions
M.commands = commands

M.config = config
M.util = util

---@return string? Binary path when executable, nil when w4 is unavailable.
function M.find_binary()
    return util.find_binary()
end

---@param opts games.wasm4.Options?
function M.setup(opts)
    config.resolve(opts)
    commands.setup()
end
M.run_action_by_id = actions.run_action_by_id

M.show_menu = actions.show_menu

return M
