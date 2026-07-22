-- #################################################################
-- /qompassai/lua/linters/mdl.lua
-- Qompass AI MDL
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'mdl',
        cmd = 'mdl',
        stdin = false,
        append_fname = true,
        args = function()
                return {
                        '--style',
                        'all',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l: %m',
                '%f:%l:%c: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]