-- /qompassai/Diver/lsp/bzl_ls.lua
-- Qompass AI Bazel LSP Spec
---@type vim.lsp.Config
return {
    cmd = {
        'bzl',
        'lsp',
        'serve',
    },
    filetypes = {
        'bzl',
    },
    root_markers = {
        'WORKSPACE',
        'WORKSPACE.bazel',
    },
}
