-- #################################################################
-- /qompassai/lua/linters/stylelint.lua
-- Qompass AI Stylelint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'stylelint',
        cmd = 'stylelint',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--formatter',
                        'unix',
                        '--stdin-filename',
                        context.filename,
                        '--',
                }
        end,
        stream = 'stderr',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %t%*[^ ] %m',
                '%f:%l:%c: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]