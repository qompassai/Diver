-- /qompassai/Diverfoam_ls.lua
-- Qompass AI Foam LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'foam-ls',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'foam',
        'OpenFOAM',
    },
    root_markers = { ---@type string[]
        '.foamcase',
        '.git',
        'system',
    },
}
