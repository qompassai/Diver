-- /qompassai/Diver/lsp/tcl_ls.lua
-- Qompass AI Tool Command Language (TCL) LSP Spec
---@source https://github.com/nmoroze/tclint

return ---@type vim.lsp.Config
{
    cmd = {
        'tclsp',
    },
    filetypes = {
        'tcl',
        'sdc',
        'xdc',
        'upf',
    },
    root_markers = {
        'tclint.toml',
        '.tclint',
        'pyproject.toml',
        '.git',
    },
    settings = {},
}
