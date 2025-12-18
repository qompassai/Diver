-- /qompassai/Diver/lsp/lean_ls.lua
-- Qompass AI Lean LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/leanprover/lean-client-js/tree/master/lean-language-server
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'lean-language-server',
        '--stdio',
        '--',
        '-M',
        '4096',
        '-T',
        '100000',
    },
    filetypes = { ---@type string[]
        'lean3',
    },
    offset_encoding = 'utf-32', ---@type string
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        fname = vim.fs.normalize(fname)
        local stdlib_dir
        do
            local _, endpos = fname:find('/lean/library')
            if endpos then
                stdlib_dir = fname:sub(1, endpos)
            end
        end
        on_dir(vim.fs.root(fname, {
            'leanpkg.toml',
            'leanpkg.path',
        }) or stdlib_dir or vim.fs.dirname(vim.fs.find('.git', {
            path = fname,
            upward = true,
        })[1]))
    end,
}
