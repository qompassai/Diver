-- /qompassai/Diver/lsp/puppet_ls.lua
-- Qompass AI Puppet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
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
    settings = {},
}
