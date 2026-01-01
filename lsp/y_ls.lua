-- /qompassai/Diver/lsp/y_ls.lua
-- Qompass AI Diver Yara LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = {
        'yls',
        '-vvv',
    },
    filetypes = {
        'yara',
    },
    root_dir = util.find_git_ancestor,
    settings = {},
}
