-- /qompassai/Diver/lsp/stylua3p_ls.lua
-- Qompass AI Stylua 3rd Party LSP Spec
--Reference: https://github.com/antonk52/lua-3p-language-servers
---@type vim.lsp.Config
return {
    cmd = {
        'stylua-3p-language-server',
    },
    filetypes = {
        'lua',
    },
    root_markers = {
        '.stylua.toml',
        'stylua.toml',
    },
    settings = {},
}
