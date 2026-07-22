-- #################################################################
-- /qompassai/lua/linters/cargo_clippy_fix.lua
-- Qompass AI Cargo Clippy Fix
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
return {
        name = 'cargo-clippy-fix',
        cmd = 'cargo',
        stdin = false,
        append_fname = false,
        args = function()
                return {
                        'clippy',
                        '--fix',
                        '--workspace',
                        '--all-features',
                        '--allow-dirty',
                        '--allow-staged',
                        '--message-format=short',
                        '--quiet',
                        '--',
                        '-D',
                        'warnings',
                        '-W',
                        'clippy::pedantic',
                        '-W',
                        'clippy::nursery',
                }
        end,
        stream = 'stderr',
        ignore_exitcode = true,
        errorformat = {
                '%f:%l:%c: %trror: %m',
                '%f:%l:%c: %tarning: %m',
                '%f:%l:%c: %m',
                '%f:%l: %m',
                '%-G%.%#',
        },
} --[[@as vim.lint.Config]]