-- /qompassai/Diver/lsp/markojs_ls.lua
-- Qompass AI MarkoJS LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'marko-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'marko',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
