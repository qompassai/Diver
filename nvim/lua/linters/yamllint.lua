-- #################################################################
-- /qompassai/lua/linters/yamllint.lua
-- Qompass AI Yamllint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'yamllint',
        cmd = 'yamllint',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--format',
                        'parsable',
                        '-',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: [%t] %m',
                '%f:%l:%c: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]