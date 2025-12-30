-- /qompassai/Diver/after/syntax/qf.lua
-- Qompass AI Diver After QuickFix Syntax
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.b.current_syntax ~= nil then
    return
end
vim.cmd([[
  syntax match QuickFixText /^.*/
]])
vim.b.current_syntax = 'qf'
