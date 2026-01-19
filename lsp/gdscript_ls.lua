-- /qompassai/Diver/lsp/gdscript.lua
-- Qompass AI Godot Script (GdScript) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local port = (function()
    local env = os.getenv('GDScript_Port')
    if env ~= nil then
        local n = assert(tonumber(env), 'Invalid GDScript_Port')
        return n --[[@as integer]]
    end
    return 6005
end)()
local cmd = vim.lsp.rpc.connect('127.0.0.1', port)
return ---@type vim.lsp.Config
{
    cmd = cmd,
    filetypes = {
        'gd',
        'gdscript',
        'gdscript3',
    },
    root_markers = {
        'project.godot',
        '.git',
    },
    settings = {},
}