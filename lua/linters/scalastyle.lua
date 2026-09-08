-- #################################################################
-- /qompassai/lua/linters/scalastyle.lua
-- Qompass AI Scalastyle
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'scalastyle',
        cmd = 'scalastyle',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--xmlOutput',
                        '--quiet',
                        '--stdin',
                        context.filename,
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