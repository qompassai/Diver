-- /qompassai/Diver/lsp/ember_ls.lua
-- Qompass AI Ember LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------------
-- https://github.com/ember-tooling/ember-language-server
-- pnpm add -g @ember-tooling/ember-language-server@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'ember-language-server',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'handlebars',
        'javascript',
        'typescript',
        'typescript.glimmer',
        'javascript.glimmer',
    },
    root_markers = { ---@type string[]
        'ember-cli-build.js',
        '.git',
    },
}
