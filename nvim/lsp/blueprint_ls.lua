-- /qompassai/Diver/lsp/blueprint_ls.lua
-- Qompass AI BluePrint Compiler LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'blueprint-compiler',
        'lsp',
    },
    cmd_env = {
        GLOB_PATTERN = vim.env.GLOB_PATTERN or '*@(.blp)',
    },
    filetypes = {
        'blueprint',
    },
    root_markers = {
        '.git',
    },
}
