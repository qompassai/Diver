-- /qompassai/Diver/lsp/served_ls.lua
-- Qompass AI Serve-D LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/Pure-D/serve-d
---
--- serve-d is launched bare over stdio. The previous spec passed
--- '--require', 'served:workspace-d': upstream's --require accepts
--- feature names only ('d', 'workspaces'), and serve-d
--- intentionally crashes on startup when a required option is
--- unsupported -- 'served:workspace-d' is a dub subpackage name,
--- not a feature, so the old cmd could never start the server.
--- '--provide http' is valid upstream but asks the client to
--- perform downloads via coded/interactiveDownload, which a
--- plain vim.lsp client does not implement; omitting it keeps
--- serve-d on its internal download path. serve-d spawns 'dub'
--- and 'dcd-server' by name, so both must be on PATH.
return ---@type vim.lsp.Config
{
    cmd = {
        'serve-d',
    },
    filetypes = {
        'd',
        'di',
        'dpp',
    },
    root_markers = {
        '.git',
        'dub.json',
        'dub.sdl',
        'meson.build',
    },
    settings = {},
}
