-- #################################################################
-- /qompassai/lua/linters/bootlint.lua
-- Qompass AI Bootlint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'bootlint',
        cmd = 'bootlint',
        stdin = false,
        append_fname = true,
        args = function()
                return {
                        '--disable',
                        'W001',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c %t%n %m',
                '%f:%l:%c %m',
                '%f:%l %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]