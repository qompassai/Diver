-- /qompassai/lua/linters/djlint.lua
-- Qompass AI DjLint
---@module 'linters.djlint'
return {
    append_fname = false,
    args = function(context)
        return {
            '--reformat',
            '--check',
            '--stdin-display-name',
            context.filename,
            '-',
        }
    end,
    cmd = 'djlint',
    errorformat = {
        '%f:%l:%c: %m',
        '%f:%l: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'djlint',
    stdin = true,
    stream = 'stderr',
} --[[@as vim.lint.Config]]
