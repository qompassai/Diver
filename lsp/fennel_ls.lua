-- /qompassai/Diver/lsp/fennel_ls.lua
-- Qompass AI Diver Fennel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = {
        offsetEncoding = {
            'utf-8',
            'utf-16',
        },
        cmd = {
            'fennel-ls',
        },
        filetypes = {
            'fennel',
        },
        root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local has_fls_project_cfg = function(path)
                local fnlpath = vim.fs.joinpath(path, 'flsproject.fnl') ---@type string
                return (vim.uv.fs_stat(fnlpath) or {}).type == 'file'
            end
            on_dir(vim.iter(vim.fs.parents(fname)):find(has_fls_project_cfg) or vim.fs(0, '.git'))
        end,
        settings = {},
    },
}