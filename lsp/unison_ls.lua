-- unison_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'nc',
        'localhost',
        os.getenv('UNISON_LSP_PORT') or '5757',
    },
    filetypes = { 'unison' },
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        on_dir(util.root_pattern('*.u')(fname))
    end,
    settings = {},
}
