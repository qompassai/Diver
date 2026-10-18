-- /qompassai/Diver/lsp/rego_ls.lua
-- Qompass AI Open Policy Agent (OPA) Rego LSP Spec
return ---@type vim.lsp.Config
{
    cmd = {
        'regols',
    },
    filetypes = {
        'rego',
    },
    root_markers = {
        '.git',
        '*.rego',
    },
    settings = {},
}
