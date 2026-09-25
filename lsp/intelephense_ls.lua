--- intelephense language-server config — starts the PHP files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `intelephense` tutor whenever you open PHP files. It only takes effect
--- if `intelephense` is installed on your computer.
---@module 'lsp.intelephense_ls'
-- /qompassai/Diver/lsp/intelephense_ls.lua
-- Qompass AI Intelephense LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://intelephense.com
-- https://github.com/bmewburn/intelephense-docs/blob/master/installation.md#initialisation-options
-- pnpm add -g intelephense@latest
return {
    cmd = { ---@type string[]
        'intelephense',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'php',
    },
    init_options = {
        storagePath = {},
        globalStoragePath = {},
        licenceKey = {},
        clearCache = {},
    },
    root_markers = { ---@type string[]
        '.git',
        'composer.json',
    },
    settings = {
        intelephense = {
            files = {
                maxSize = 1000000, ---@type integer
            },
        },
    },
}
