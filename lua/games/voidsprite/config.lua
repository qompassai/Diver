-- /qompassai/Diver/lua/games/voidsprite/config.lua
-- Qompass AI Voidsprite Config
--- Options for voidsprite, Matt's pixel-art editor (AUR voidsprite-git,
--- counter185/voidsprite: free C++/SDL3 pixel-art editor).
---
--- Verified CLI surface (2026-09-28): the upstream .desktop file ships
--- `Exec=voidsprite %U`, i.e. the binary opens files passed as arguments.
--- No headless/batch export CLI is documented upstream, so this module
--- wires GUI launch only; PNG export happens inside the editor and the
--- TIC-80 import bridge lives in `games.tic80.actions`.
---@module 'games.voidsprite.config'

---@class games.voidsprite.Options
---@field bin string? Binary name or absolute path of the voidsprite executable.

local M = {}

M.binaries = { 'voidsprite' }

M.env_names = {
    'NVIM_VOIDSPRITE_BIN',
    'VOIDSPRITE_BIN',
}

M.group_order = {
    'Editor',
    'TIC-80',
}

M.output_filetype = 'voidsprite-output'

---Native session formats (.voidsnv3 documented upstream) plus the PNG
---interchange format used for the TIC-80 sprite-sheet pipeline.
---@type string[]
M.sprite_extensions = {
    '.voidsn',
    '.voidsnv3',
    '.png',
}

---@param opts games.voidsprite.Options?
---@return string bin Resolved binary name or path (unvalidated).
function M.resolve(opts)
    opts = opts or {}
    return opts.bin or 'voidsprite'
end

return M
