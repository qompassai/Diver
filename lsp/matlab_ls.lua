-- /qompassai/Diver/lsp/matlab_ls.lua
-- Qompass AI MatLab LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/mathworks/MATLAB-language-server
vim.lsp.config['matlab_ls'] = {
    cmd = {
        'matlab-language-server',
        '--stdio',
    },
    filetypes = {
        'matlab',
    },
    root_markers = {
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
