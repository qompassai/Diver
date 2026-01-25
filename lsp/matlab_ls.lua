-- /qompassai/Diver/lsp/matlab_ls.lua
-- Qompass AI Diver MatLab LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = { ---@type string[]
        'matlab-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'matlab',
    },
    root_markers = { ---@type string[]
        'git',
    },
    settings = {
        MATLAB = {
            indexWorkspace = true,
            installPath = '/usr/bin/matlab-language-server',
            matlabConnectionTiming = 'onStart',
            telemetry = false,
        },
    },
}