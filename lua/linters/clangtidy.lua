-- /qompassai/Diver/lua/linters/clangtidy.lua
-- Qompass AI Diver ClangTidy Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local pattern = [[([^:]*):(%d+):(%d+): (%w+): ([^[]+)]]
local groups = {
    'file',
    'lnum',
    'col',
    'severity',
    'message',
}
local severity_map = {
    ['error'] = vim.diagnostic.severity.ERROR, ---@type integer
    ['warning'] = vim.diagnostic.severity.WARN, ---@type integer
    ['information'] = vim.diagnostic.severity.INFO, ---@type integer
    ['hint'] = vim.diagnostic.severity.HINT, ---@type integer
    ['note'] = vim.diagnostic.severity.HINT, ---@type integer
}
return {
    cmd = 'clang-tidy',
    stdin = false,
    args = {
        '--quiet',
    },
    ignore_exitcode = true,
    parser = require('config.core.parser').from_pattern(pattern, groups, severity_map, {
        ['source'] = 'clang-tidy', ---@type string
    }),
}