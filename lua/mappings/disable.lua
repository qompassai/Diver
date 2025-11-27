-- /qompassai/Diver/lua/mappings/disable.lua
-- Qompass AI Diver Disabled Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}

M.setup_disable = function()
    vim.keymap.set('n', 'gc', '<Nop>', {noremap = true})
    vim.keymap.set('n', 'gcc', '<Nop>', {noremap = true})
    vim.keymap.set('x', 'gc', '<Nop>', {noremap = true})
    vim.keymap.set('o', 'gc', '<Nop>', {noremap = true})
end

return M
