-- /qompassai/lua/linters/vint.lua
-- Qompass AI Vint
---@module 'linters.vint'
return {
    append_fname = false,
    args = function(context)
        return {
            '--enable-neovim',
            '--stdin-display-name',
            context.filename,
            '-',
        }
    end,
    cmd = 'vint',
    errorformat = {
        '%f:%l:%c: %t%*[^ ] %m',
        '%f:%l:%c: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'vint',
    stdin = true,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
