-- /qompassai/Diver/lua/games/redot/character.lua
-- Qompass AI Redot Character Builder
---@module 'games.redot.character'
-- Redot character interchange artifacts. Thin wrapper over the
-- shared factory (games.shared.godot_character): this file supplies
-- the Redot descriptor and the Redot-named LuaCATS classes; all
-- behavior lives in the factory. Pure at require time.

---@class RedotCharacterOpts
---@field bin? string explicit engine binary override
---@field fps? number bake fps override
---@field name? string character name override (sanitized)

---@class RedotInterchangeFile
---@field path string relative path
---@field content string file text

return require('games.shared.godot_character').build({
    binaries = { 'redot4', 'redot', 'Redot', 'Redot_v4' },
    display = 'Redot',
    env_names = { 'NVIM_REDOT_BIN', 'REDOT_BIN', 'REDOT4_BIN' },
    manifest_format = 'diver-character-redot',
    module_path = 'games/redot/character.lua',
})
