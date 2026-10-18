-- /qompassai/Diver/lsp/proto_ls.lua
-- Qompass AI Protobuf LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'protols',
    },
    filetypes = { ---@type string[]
        'proto',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
