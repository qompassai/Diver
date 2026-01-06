-- /qompassai/Diver/lsp/turbo_ls.lua
-- Qompass AI Javascript (JS) Turbo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://www.npmjs.com/package/turbo-language-server | https://turbo.hotwired.dev/
-- pnpm add -g turbo-language-server@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'turbo-language-server',
        '--stdio',
    },
    filetypes = {
        'blade',
        'eruby',
        'html',
        'php',
        'ruby',
    },
    root_markers = {
        'Gemfile',
        '.git',
    },
    settings = {},
}