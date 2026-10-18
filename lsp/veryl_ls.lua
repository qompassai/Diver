-- /qompassai/Diver/lsp/veryl_ls.lua
-- Qompass AI Veryl LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'veryl-ls',
    },
    filetypes = { ---@type string[]
        'veryl',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
