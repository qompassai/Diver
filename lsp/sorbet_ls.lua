-- /qompassai/Diver/lsp/sorbet_ls.lua
-- Qompass AI Sorbet LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'srb',
        'tc',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'ruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
}
