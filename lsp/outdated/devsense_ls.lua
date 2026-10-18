-- /qompassai/Diver/lsp/devsense_ls.lua
-- Qompass AI Devsense-PHP LSP Spec
--Reference: https://www.npmjs.com/package/devsense-php-ls
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'devsense-php-ls',
        '--stdio',
    },
    filetypes = {
        'php',
    },
    root_markers = {
        'composer.json',
        '.git',
    },
    init_options = {
        ['0'] = '{}',
    },
}
