-- /qompassai/Diver/lsp/rego_ls.lua
-- Qompass AI Open Policy Agent (OPA) Rego LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://github.com/kitagry/regols | https://www.openpolicyagent.org/docs
-- go install github.com/kitagry/regols@latest
vim.lsp.config['rego_ls'] = {
    cmd = {
        'regols',
    },
    filetypes = {
        'rego',
    },
    root_markers = {
        '.git',
        '*.rego',
    },
}
