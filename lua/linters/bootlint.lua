-- #################################################################
-- /qompassai/lua/linters/bootlint.lua
-- Qompass AI Bootlint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
    append_fname = true,
    args = function()
        return {
            '--disable',
            'W001',
        }
    end,
    cmd = 'bootlint',
    errorformat = {
        '%f:%l:%c %t%n %m',
        '%f:%l:%c %m',
        '%f:%l %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'bootlint',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
