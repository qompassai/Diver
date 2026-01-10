-- /qompassai/Diver/lsp/typos_ls.lua
-- Qompass AI Typos LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/crate-ci/typos/blob/master/docs/reference.md
---@type vim.lsp.Config
return {
    cmd = {
        'typos-lsp',
    },
    cmd_env = {
        RUST_LOG = 'error',
    },
    init_options = {
        --config = '$XDG_CONFIG_HOME/typos-lsp/.typos.toml',
        diagnosticSeverity = 'Info',
    },
    root_markers = {
        'typos.toml',
        '_typos.toml',
        '.typos.toml',
        'pyproject.toml',
        'Cargo.toml',
    },
    settings = {
        typos = {
            default = {
                binary = false,
                ['check-file'] = true,
                ['check-filename'] = true,
                ['extend-ignore-re'] = {},
                ['extend-ignore-identifiers-re'] = {},
                locale = 'en',
                unicode = true,
            },
            files = {
                ['extend-exclude'] = {},
                ['ignore-hidden'] = true,
                ['ignore-files'] = true,
                ['ignore-dot'] = true,
                ['ignore_vcs'] = true,
            },
        },
    },
}