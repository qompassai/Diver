-- /qompassai/Diver/lsp/css_ls.lua
-- Qompass AI VSCode Css LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
----------------------------------------------------------------
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
---@type vim.lsp.Config
return {
    capabilities = capabilities,
    cmd = { ---@type string[]
        'vscode-css-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'css',
        'scss',
        'less',
    },
    init_options = { ---@type table
        provideFormatter = true,
    },
    root_markers = { ---@type string[]
        '.git',
        'package.json',
    },
    settings = { ---@type table
        css = {
            validate = true,
        },
        scss = {
            validate = true,
        },
        less = {
            validate = true,
        },
        cssVariables = { ---@type string[]
            lookupFiles = {
                '**/*.css',
                '**/*.scss',
                '**/*.sass',
                '**/*.less',
            },
        },
    },
}
