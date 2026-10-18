-- /qompassai/Diver/lsp/diagnostic_ls.lua
-- Qompass AI Diagnostic LSP Spec
-- Reference: https://github.com/iamcco/diagnostic-languageserver
-- pnpm add -g diagnostic-languageserver@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'diagnostic-languageserver',
        '--stdio',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    filetypes = {},
}
