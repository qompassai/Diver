-- /qompassai/Diver/lsp/flow_ls.lua
-- Qompass AI Diver Flow LSP Spec
---@source  https://github.com/facebook/flow
---@type vim.lsp.Config
return {
    cmd = {
        'npx',
        '--no-install',
        'flow',
        'lsp',
    },
    filetypes = {
        'javascript',
        'javascriptreact',
        'javascript.jsx',
    },
    root_markers = {
        '.flowconfig',
    },
}
