-- /qompassai/lua/linters/scalastyle.lua
-- Qompass AI Scalastyle
---@module 'linters.scalastyle'
return {
    append_fname = false,
    args = function(context)
        return {
            '--xmlOutput',
            '--quiet',
            '--stdin',
            context.filename,
        }
    end,
    cmd = 'scalastyle',
    errorformat = {
        '%f:%l: %m',
        '%f:%l:%c: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'scalastyle',
    stdin = true,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
