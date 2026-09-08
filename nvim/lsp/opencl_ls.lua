-- /qompassai/Diver/lsp/opencl_ls.lua
-- Qompass AI OpenCL LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'opencl-language-server',
        '--stdio',
        '--enable-file-logging',
        '--log-file',
        vim.fn.stdpath('cache') .. '/opencl-language-server.log',
        '--log-level',
        '5',
    },
    filetypes = { ---@type string[]
        'c',
        'cpp',
        'opencl',
    },
    root_markers = { ---@type string[]
        '.git',
    },
}
