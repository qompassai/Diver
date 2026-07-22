-- #################################################################
-- /qompassai/lua/linters/puppet.lua
-- Qompass AI Puppet Lint
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'puppet-lint',
        cmd = 'puppet-lint',
        stdin = false,
        append_fname = true,
        args = function()
                return {
                        '--log-format',
                        '%{fullpath}:%{line}:%{column}:%{kind}:%{check}:%{message}',
                }
        end,
        stream = 'stdout',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c:%t:%*[a-zA-Z0-9_ -]:%m',
                '%f:%l:%c:%*[a-z]:%*[a-zA-Z0-9_ -]:%m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]