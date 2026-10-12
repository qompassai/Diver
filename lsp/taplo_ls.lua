-- /qompassai/Diver/lsp/taplo.lua
-- Qompass AI Taplo LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'taplo',
        'lsp',
        'stdio',
    },
    filetypes = {
        'toml',
    },
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, { '.taplo.toml', 'taplo.toml', '.git' })
        if root == nil then
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            if bufname ~= '' then
                root = vim.fs.dirname(bufname)
            end
        end
        if root ~= nil then
            on_dir(root)
        end
    end,
    root_markers = {
        '.taplo.toml',
        'taplo.toml',
        '.git',
    },
    settings = {},
}
