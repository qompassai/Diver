-- /qompassai/Diver/lsp/intelephense_ls.lua
-- Qompass AI Intelephense LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://intelephense.com |  https://github.com/bmewburn/intelephense-docs/blob/master/installation.md#initialisation-options
-- pnpm add -g intelephense@latest
return {
    cmd = { ---@type string[]
        'intelephense',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'php',
    },
    init_options = {
        storagePath = {},
        globalStoragePath = {},
        licenceKey = {},
        clearCache = {},
    },
    root_markers = { ---@type string[]
        '.git',
        'composer.json',
    },
    settings = {
        intelephense = {
            files = {
                maxSize = 1000000, ---@type integer
            },
        },
    },
}
