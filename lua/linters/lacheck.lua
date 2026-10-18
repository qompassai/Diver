-- /qompassai/lua/linters/lacheck.lua
-- Qompass AI Lacheck
---@module 'linters.lacheck'
return {
    append_fname = false,
    args = function(context)
        return {
            context.filename,
        }
    end,
    cmd = 'lacheck',
    errorformat = {
        '"%f", line %l: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'lacheck',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
