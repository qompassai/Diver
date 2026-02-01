-- /qompassai/Diver/after/plugin/python.lua
-- Qompass AI Diver After Filetype Plugin Python Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
M = {}
local api = vim.api
local fn = vim.fn
local group = api.nvim_create_augroup('Python', {
    clear = true,
})
local header = require('utils.docs')
local log = vim.log
local notify = vim.notify
api.nvim_set_option_value('shiftwidth', 4, {
    buf = 0,
})
api.nvim_set_option_value('tabstop', 4, {
    buf = 0,
})
api.nvim_set_option_value('expandtab', true, {
    buf = 0,
})
api.nvim_create_autocmd('BufNewFile', {
    group = group,
    pattern = {
        '*.py',
    },
    callback = function()
        if api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '' then
            return
        end
        local filepath = fn.expand('%:p')
        local shebang = '#!/usr/bin/env python3'
        local hdr = header.make_header(filepath, '#')
        local lines = {
            shebang,
            '',
        }
        vim.list_extend(lines, hdr)
        api.nvim_buf_set_lines(0, 0, 0, false, lines)
        vim.cmd('normal! G')
    end,
})

local python_errorformat = '%A%\\s%#File "%f"\\, line %l\\, in%.%#'
python_errorformat = python_errorformat .. ',%+CFailed example:%.%#'
python_errorformat = python_errorformat .. ',%-G*%\\{70%\\}'
python_errorformat = python_errorformat .. ',%-G%*\\d items had failures:'
python_errorformat = python_errorformat .. ',%-G%*\\s%*\\d of%*\\s%*\\d in%.%#'
python_errorformat = python_errorformat .. ',%E  File "%f"\\, line %l'
python_errorformat = python_errorformat .. ',%-C%p^'
python_errorformat = python_errorformat .. ',%+C  %m'
python_errorformat = python_errorformat .. ',%Z  %m'
M.python = python_errorformat
api.nvim_create_user_command('PyLintAll', function()
    local file = fn.expand('%:p')
    local cmds = {
        {
            'ruff',
            'check',
            file,
        },
        {
            'bandit',
            '-q',
            file,
        },
        {
            'vulture',
            file,
        },
        {
            'pyrefly',
            file,
        },
    }
    for _, cmd in ipairs(cmds) do
        if fn.executable(cmd[1]) == 1 then
            fn.jobstart(cmd, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data, _)
                    if not data then
                        return
                    end
                    local out = table.concat(data, '')
                    if out ~= '' then
                        vim.schedule(function()
                            notify(table.concat(cmd, ' ') .. ': ' .. out, log.levels.INFO)
                        end)
                    end
                end,
            })
        end
    end
end, {})
return M
