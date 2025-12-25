-- /qompassai/Diver/ftdetect/schelp.lua
-- Qompass AI Filetype Detect SCHelp Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
  pattern = '*.schelp',
  callback = function(ev)
    vim.bo[ev.buf].filetype = 'scdoc'
  end,
})