-- /qompassai/Diver/lsp/chpl_ls.lua
-- Qompass AI Diver Chapel LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'chpl-language-server',
        'chplcheck',
    },
    filetypes = {
        'chpl',
    },
    root_markers = {
        'chpl-language-server.cfg',
        '.chpl-language-server.cfg',
        '.cls-commands.json',
        '.cls-commands.jsonc',
        '.git',
        'Mason.toml',
    },
    settings = {},
}
