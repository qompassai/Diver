-- /qompassai/lsp/starp_ls.lua
-- Qompass AI Starp Ls
---@type vim.lsp.Config
return {
    cmd = {
        'starpls',
    },
    filetypes = {
        'bzl',
    },
    root_markers = {
        'WORKSPACE',
        'WORKSPACE.bazel',
        'MODULE.bazel',
    },
}
