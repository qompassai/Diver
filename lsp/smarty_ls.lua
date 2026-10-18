-- /qompassai/Diver/lsp/smarty_ls.lua
-- Qompass AI Smarty LSP Spec
--pnpm add -g  vscode-smarty-langserver-extracted
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'smarty-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'smarty',
    },
    room_markers = { ---@type string[]
        'composer.json',
        '.git',
    },
    settings = {
        smarty = {
            pluginDirs = {},
        },
        css = {
            validate = true, ---@type boolean
        },
    },
    init_options = {
        storageDir = vim.NIL,
    },
}
