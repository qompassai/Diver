-- /qompassai/Diver/lsp/nushell_ls.lua
-- Qompass AI NuShell LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nushell/nushell
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'nu',
        '--lsp',
    },
    filetypes = { ---@type string[]
        'nu',
    },
    root_dir = function(bufnr, on_dir)
        on_dir(vim.fs(bufnr, { '.git' }) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
    root_markers = { ---@type string[]
        '.git',
    },
}
