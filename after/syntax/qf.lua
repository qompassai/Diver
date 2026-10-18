-- /qompassai/Diver/after/syntax/qf.lua
-- Qompass AI Diver After QuickFix Syntax
if vim.b.current_syntax ~= nil then
    return
end
vim.cmd([[
  syntax match QuickFixText /^.*/
]])
vim.b.current_syntax = 'qf'
