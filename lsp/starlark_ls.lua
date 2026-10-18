-- /qompassai/Diver/lsp/starlark_ls.lua
-- Qompass AI Starlark LSP Spec
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'starlark',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'star',
        'bzl',
        'BUILD.bazel',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
