-- /qompassai/Diver/lsp/dts_ls.lua
-- Qompass AI Device Tree Source (DTS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/igor-prusov/dts-lsp
-- cargo install dts-lsp
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'dts-lsp',
    },
    filetypes = { ---@type string[]
        'dts',
        'dtsi',
        'overlay',
    },
    root_markers = { ---@type string[]
        '.git',
    },
    settings = {},
},
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'dts',
        callback = function(ev)
            local bufnr = ev.buf
            vim.lsp.start({
                name = 'dts-lsp',
                cmd = {
                    'dts-lsp',
                },
                bufnr = bufnr,
                root_dir = vim.fs.dirname(vim.fs.find({
                    '.git',
                }, { upward = true })[1]),
            })
        end,
    })