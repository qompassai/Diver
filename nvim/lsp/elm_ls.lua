-- /qompassai/Diver/lsp/elm_ls.lua
-- Qompass AI Elm LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'elm-language-server',
    },
    filetypes = { ---@type string[]
        'elm',
    },
    init_options = {
        elmReviewDiagnostics = 'warning',
        skipInstallPackageConfirmation = false,
        disableElmLSDiagnostics = false,
        onlyUpdateDiagnosticsOnSave = false,
    },
    capabilities = {
        offsetEncoding = {
            'utf-8',
            'utf-16',
        },
    },
    root_markers = { ---@type string[]
        'elm.json',
    },
}
