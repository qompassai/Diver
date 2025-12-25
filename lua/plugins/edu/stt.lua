-- /qompassai/Diver/lua/plugins/edu/stt.lua
-- Qompass AI Diver Speech-To-Text (STT) Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
    'eyalk11/speech-to-text.nvim',
    config = function()
        vim.keymap.set('n', '<C-L>', ':Voice<CR>')
        vim.keymap.set('i', '<C-L>', '<C-R>=GetVoice()<CR>')
    end,
}
