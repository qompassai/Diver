-- /qompassai/Diver/lsp/facility_ls.lua
-- Qompass AI Facility Language Server
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/FacilityApi/FacilityLanguageServer
vim.lsp.config['facility_ls'] = {
    cmd = {
        'dotnet',
        vim.fn.expand('$XDG_DATA_HOME/facility-language-server/libexec/Facility.LanguageServer.dll'),
    },
    filetypes = {
        'fsd',
    },
    root_markers = {
        '.git',
    },
}
