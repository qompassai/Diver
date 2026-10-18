-- /qompassai/lua/linters/html_validate.lua
-- Qompass AI HTML Validate
---@module 'linters.html_validate'
return {
    append_fname = true,
    args = function()
        return {
            '--formatter',
            'checkstyle',
        }
    end,
    cmd = 'html-validate',
    errorformat = {
        '%f:%l:%c: %m',
        '%f:%l: %m',
        '%-G%.%#',
    },
    ignore_exitcode = true,
    name = 'html-validate',
    stdin = false,
    stream = 'stdout',
} --[[@as vim.lint.Config]]
