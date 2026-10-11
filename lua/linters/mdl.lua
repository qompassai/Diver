-- #################################################################
-- /qompassai/lua/linters/mdl.lua
-- Qompass AI MDL
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
    append_fname = true,
    args = function()
        return {
            '--style',
            'all',
        }
    end,
    cmd = 'mdl',
    errorformat = {
        '%f:%l: %m',
        '%f:%l:%c: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'mdl',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
