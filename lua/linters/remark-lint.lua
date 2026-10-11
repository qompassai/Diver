-- #################################################################
-- /qompassai/lua/linters/remark_lint.lua
-- Qompass AI Remark Lint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
    append_fname = true,
    args = function()
        return {
            '--frail',
            '--quiet',
            '--output',
            '--use',
            'remark-preset-lint-recommended',
        }
    end,
    cmd = 'remark',
    errorformat = {
        '%f:%l:%c: %m',
        '%f:%l: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'remark-lint',
    stdin = false,
    stream = 'stderr',
} --[[@as vim.lint.Config]]
