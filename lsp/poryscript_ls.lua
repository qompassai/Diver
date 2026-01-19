-- /qompassai/Diver/lsp/lua_ls.lua
-- Qompass AI Diver Lua_ls LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'poryscript-pls',
    },
    filetypes = {
        'pory',
    },
    root_markers = {
        '.git',
    },
}
