-- #################################################################
-- /qompassai/lua/linters/dotenv-linter.lua
-- Qompass AI Dotenv Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'dotenv-linter',
        cmd = 'dotenv-linter',
        stdin = false,
        append_fname = true,
        args = function()
                return {}
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l %m',
                '%f:%l:%c %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]