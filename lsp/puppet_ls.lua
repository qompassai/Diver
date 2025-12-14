-- /qompassai/Diver/lsp/puppet_ls.lua
-- Qompass AI Puppet Editor Services LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['puppet_ls'] = {
    cmd = {
        'ruby',
        'puppet-languageserver',
        '--stdio',
        '--timeout=0',
        '--puppet-settings=--moduledir,/etc/puppetlabs/code/modules',
    },
    filetypes = {
        'puppet',
    },
    root_markers = {
        'metadata.json',
        'metadata.jsonc',
        '.git',
    },
}
