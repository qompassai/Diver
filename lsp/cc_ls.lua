-- /qompassai/Diver/lsp/ccls.lua
-- Qompass AI C/C++/ObjC (CC) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['cc_ls'] = {
    cmd = {
        'ccls',
    },
    filetypes = {
        'c',
        'cpp',
        'objc',
        'objcpp',
        'cuda',
    },
    offset_encoding = 'utf-8',
}
