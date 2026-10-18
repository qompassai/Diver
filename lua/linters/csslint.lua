-- /qompassai/lua/linters/csslint.lua
-- Qompass AI CSSLint
---@module 'linters.csslint'
return {
    append_fname = false,
    args = function(context)
        return {
            '--format=compact',
            '--quiet',
            '--stdin',
            context.filename,
        }
    end,
    cmd = 'csslint',
    errorformat = {
        '%f: line %l, col %c, %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'csslint',
    stdin = true,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
