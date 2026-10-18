-- /qompassai/Diver/lsp/awk_ls.lua
-- Qompass AI Awk_ls LSP Config
--Reference:  https://github.com/Beaglefoot/awk-language-server/
---@type vim.lsp.Config
return {
    cmd = {
        'awk-language-server',
    },
    filetypes = {
        'awk',
    },
}
