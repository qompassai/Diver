-- /qompassai/Diver/lsp/cypher_ls.lua
-- Qompass AI Cypher LSP Spec
-- pnpm add -g -g @neo4j-cypher/language-server@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'cypher-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'cypher',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
