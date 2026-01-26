-- /qompassai/Diver/lua/linters/eslint_d.lua
-- Qompass AI Diver Eslint_d Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
    cmd = function()
        local local_binary = vim.fn.fnamemodify('./node_modules/.bin/' .. 'eslint_d', ':p')
        return vim.uv.fs_stat(local_binary) and local_binary or 'eslint_d'
    end,
    args = {
        '--format',
        'json',
        '--stdin',
        '--stdin-filename',
        function()
            return vim.api.nvim_buf_get_name(0)
        end,
    },
    stdin = true,
    stream = 'stdout',
    ignore_exitcode = true,
    parser = function(output, bufnr)
        if string.find(output, 'Error: Could not find config file') then
            return {}
        end
        local result = require('lint.linters.eslint').parser(output, bufnr) ---@type table
        return result
    end,
}