-- /qompassai/Diver/lsp/puppet_ls.lua
-- Qompass AI Puppet Editor Services LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ruby',
        'puppet-languageserver',
        '--stdio',
        '--timeout=0',
        '--puppet-settings=--moduledir,/etc/puppetlabs/code/modules',
    },
    filetypes = { ---@type string[]
        'puppet',
    },
    root_markers = { ---@type string[]
        'metadata.json',
        'metadata.jsonc',
        '.git',
    },
}
