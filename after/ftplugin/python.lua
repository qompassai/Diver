-- /qompassai/Diver/after/plugin/python.lua
-- Qompass AI Diver After Filetype Plugin Python Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
M = {}
local a = vim.api
a.nvim_set_option_value('shiftwidth', 4, {
    buf = 0,
})
a.nvim_set_option_value('tabstop', 4, {
    buf = 0,
})
a.nvim_set_option_value('expandtab', true, {
    buf = 0,
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
return M

