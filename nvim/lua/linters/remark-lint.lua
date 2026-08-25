-- #################################################################
-- /qompassai/lua/linters/remark_lint.lua
-- Qompass AI Remark Lint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'remark-lint',
        cmd = 'remark',
        stdin = false,
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
        stream = 'stderr',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %m',
                '%f:%l: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]