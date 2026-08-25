-- #################################################################
-- /qompassai/lua/linters/vint.lua
-- Qompass AI Vint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'vint',
        cmd = 'vint',
        stdin = true,
        append_fname = false,
        args = function(context)
                return {
                        '--enable-neovim',
                        '--stdin-display-name',
                        context.filename,
                        '-',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %t%*[^ ] %m',
                '%f:%l:%c: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]