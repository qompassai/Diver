-- /qompassai/Diver/lsp/turtle_ls.lua
-- Qompass AI Turtle LSP Spec
--pnpm add -g turtle-language-server@latest
--Reference:
---@type vim.lsp.Config
return {
    cmd = {
        'node',
        'turtle-language-server',
        '--stdio',
    },
    filetypes = {
        'turtle',
        'ttl',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
