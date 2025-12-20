-- /qompassai/Diver/lsp/lean_ls.lua
-- Qompass AI Lean LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/leanprover/lean-client-js/tree/master/lean-language-server
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
    ---@param bufnr integer
    root_dir = function(bufnr, on_dir) ---@param on_dir fun(dir: string)
        local fname = vim.api.nvim_buf_get_name(bufnr) ---@type string
        fname = vim.fs.normalize(fname) ---@type string
        local stdlib_dir ---@type string|nil
        do
            local _, endpos = fname:find('/lean/library')
            if endpos then
                stdlib_dir = fname:sub(1, endpos) ---@type string|nil
            end
        end
        local root = vim.fs.root(fname, { ---@type string|nil
            'leanpkg.toml',
            'leanpkg.path',
        })
        local git_dir = vim.fs.find('.git', { ---@type string|nil
            path = fname,
            upward = true, ---@type boolean
        })[1]
        local dir = root ---@type string
            or stdlib_dir
            or (git_dir and vim.fs.dirname(git_dir))
            or vim.fs.dirname(fname)
        on_dir(dir)
    end,
}
