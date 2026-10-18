-- /qmopassai/Diver/lsp/coffeesense_ls.lua
-- Qompass AI CoffeeScript LSP Spec
-- References:  https://github.com/phil294/coffeesense
-- pnpm add -g coffeesense-language-server@latest
---@type vim.lsp.Config
return {
    cmd = {
        'coffeesense-language-server',
        '--stdio',
    },
    filetypes = {
        'coffee',
    },
    root_markers = {
        'package.json',
    },
}
