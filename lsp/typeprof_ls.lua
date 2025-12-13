-- /qompassai/Diver/lsp/typeprof_ls.lua
-- Qompass AI Typeprof LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/ruby/typeprof
--gem install typeprof
vim.lsp.config['typeprof_ls'] = {
    cmd = {
        'typeprof',
        '--lsp',
        '--stdio',
    },
    filetypes = {
        'ruby',
        'eruby',
    },
    root_markers = {
        'Gemfile',
        '.git',
    },
}
