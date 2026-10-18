-- /qompassai/Diver/lsp/nx_ls.lua
-- Qompass AI NX Workspace LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nxls',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'json',
        'jsonc',
    },
    root_markers = { ---@type string[]
        'nx.jsonc',
        'workspace.jsonc',
        'project.jsonc',
        '.git',
    },
}
