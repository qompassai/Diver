-- /qompassai/Diver/lua/games/voidsprite/init.lua
-- Qompass AI Voidsprite Native Tooling
--- Native voidsprite tooling: launch the editor against the current sprite
--- file and bridge PNG sprite sheets into TIC-80 carts -- no plugin.
---
--- Matt's pixel-art editor is voidsprite (AUR voidsprite-git); it is
--- Aseprite-compatible in spirit but this module does not reuse
--- `games.aseprite`: the aseprite module is built around Aseprite's
--- `-b`/`--script` batch CLI and preferences schema, none of which is
--- documented for voidsprite. The only verified voidsprite CLI surface is
--- `voidsprite <file>`, so this module stays small on purpose.
---@module 'games.voidsprite'

local actions = require('games.voidsprite.actions')
local commands = require('games.voidsprite.commands')
local config = require('games.voidsprite.config')
local util = require('games.voidsprite.util')

local M = {}
M.actions = actions
M.commands = commands

M.config = config
M.util = util

---@param opts games.voidsprite.Options?
function M.setup(opts)
    util.configure(opts)
    commands.setup()
end
M.run_action_by_id = actions.run_action_by_id

M.show_menu = actions.show_menu

return M
