-- #################################################################
-- /qompassai/lua/linters/djlint.lua
-- Qompass AI DjLint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'djlint',
        cmd = 'djlint',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--reformat',
                        '--check',
                        '--stdin-display-name',
                        context.filename,
                        '-',
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