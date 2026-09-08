-- #################################################################
-- /qompassai/lua/linters/html_validate.lua
-- Qompass AI HTML Validate
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'html-validate',
        cmd = 'html-validate',
        stdin = false,
        append_fname = true,
        args = function()
                return {
                        '--formatter',
                        'checkstyle',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %m',
                '%f:%l: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]