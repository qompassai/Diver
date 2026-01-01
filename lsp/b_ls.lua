-- /qompassai/Diver/lsp/b_ls.lua
-- Qompass AI B-lang LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = nil,
    filetypes = {
        'b',
        'eventb',
    },
    root_markers = {
        '.git',
        '.project',
        '.b-language',
    },
    ---@diagnostic disable-next-line: assign-type-mismatch
    get_root_dir = function(fname)
        return vim.fs.root(fname, { '.git', '.project' }) or vim.loop.cwd()
    end,
    on_new_config = function(config, root_dir)
        config.host = '127.0.0.1'
        config.port = 55555
        config.root_dir = root_dir
    end,
    settings = {
        bLanguageServer = {
            debugMode = false,
            performanceHints = true,
            probHome = 'DEFAULT',
            strictChecks = true,
            wdChecks = true,
        },
    },
}
