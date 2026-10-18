-- /qompassai/Diver/lsp/bazelrc_ls.lua
-- Qompass AI GHDL Bazelrc LSP Config
-- pnpm add -g git+https://github.com/salesforce-misc/bazelrc-lsp.git
vim.filetype.add({
    pattern = {
        ['.*.bazelrc'] = 'bazelrc',
    },
})
---@type vim.lsp.Config
return {
    cmd = {
        'bazelrc-lsp',
        'lsp',
    },
    filetypes = {
        'bazelrc',
    },
    root_markers = {
        '.git',
        '.bazelrc',
    },
}
