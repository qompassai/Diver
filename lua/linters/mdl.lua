-- /qompassai/lua/linters/mdl.lua
-- Qompass AI MDL
---@module 'linters.mdl'
return {
    append_fname = true,
    args = function()
        return {
            '--style',
            'all',
        }
    end,
    cmd = 'mdl',
    errorformat = {
        '%f:%l: %m',
        '%f:%l:%c: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'mdl',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
