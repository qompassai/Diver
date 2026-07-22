-- #################################################################
-- /qompassai/lua/linters/proselint.lua
-- Qompass AI Proselint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'proselint',
        cmd = 'proselint',
        stdin = false,
        append_fname = true,
        args = function()
                return {}
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %m',
                '%f:%l: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]