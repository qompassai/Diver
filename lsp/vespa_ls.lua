-- /qompassai/Diver/lsp/vespa_ls.lua
-- Qompass AI Diver Vespa LSP
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.filetype.add({
    extension = {
        profile = 'sd',
        sd = 'sd',
        yql = 'yql',
    },
})
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'java',
        '-jar',
        'vespa-language-server.jar',
    },
    filetypes = { ---@type string[]
        'sd',
        'profile',
        'yql',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
