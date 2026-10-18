-- /qompassai/Diver/lsp/uiua_ls.lua
-- Qompass AI Diver UIUA LSP Spec
---@source  https://github.com/uiua-lang/uiua/
---@see cargo install --git https://github.com/uiua-lang/uiua uiua -F full
return ---@type vim.lsp.Config
{
    cmd = {
        'uiua',
        'lsp',
    },
    filetypes = {
        'uiua',
    },
    root_markers = {
        '.git',
        'main.ua',
        '.fmt.ua',
    },
}
