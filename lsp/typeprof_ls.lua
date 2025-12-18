-- /qompassai/Diver/lsp/typeprof_ls.lua
-- Qompass AI Typeprof LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/ruby/typeprof
--gem install typeprof
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'typeprof',
        '--lsp',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'ruby',
        'eruby',
    },
    root_markers = { ---@type string[]
        'Gemfile',
        '.git',
    },
}
