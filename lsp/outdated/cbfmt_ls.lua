-- /qompassai/Diver/lsp/cbfmt_ls.lua
-- Qompass AI Codeblock Formatter Spec
vim.lsp.config['cbfmt_ls'] = {
    cmd = {
        'cbfmt',
    },
    filetypes = {
        'markdown',
        'md',
        'org',
        'rst',
    },
    codeActionProvider = false,
    colorProvider = false,
    semanticTokensProvider = nil,
    settings = {
        cbfmt = {},
    },
}
