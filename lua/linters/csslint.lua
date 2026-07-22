-- #################################################################
-- /qompassai/lua/linters/csslint.lua
-- Qompass AI CSSLint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
    name = 'csslint',
    cmd = 'csslint',
    stdin = true,
    append_fname = false,
    args = function(context)
        return {
            '--format=compact',
            '--quiet',
            '--stdin',
            context.filename,
        }
    end,
    stream = 'stdout',
    ignore_exitcode = true,
    errorformat = {
        '%f: line %l, col %c, %m',
        '%-G%.%#',
    },
} --[[@as vim.lint.Config]]