-- #################################################################
-- /qompassai/lua/linters/chktex.lua
-- Qompass AI Diver ChkTeX Linter Spec
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'chktex',
        cmd = 'chktex',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '-q',
                        '-I0',
                        '-f',
                        '%f:%l:%c:%d:%k:%n:%m',
                        '-',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c:%d:%k:%n:%m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]