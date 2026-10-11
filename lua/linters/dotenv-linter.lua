-- #################################################################
-- /qompassai/lua/linters/dotenv-linter.lua
-- Qompass AI Dotenv Linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
    append_fname = true,
    args = function()
        return {}
    end,
    cmd = 'dotenv-linter',
    errorformat = {
        '%f:%l %m',
        '%f:%l:%c %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'dotenv-linter',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
