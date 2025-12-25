-- /qompassai/Diver/ftdetect/cypher.lua
-- Qompass AI Filetype Detect Cypher Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_autocmd({
  'BufRead',
  'BufNewFile' }, {
  pattern = '*.cypher',
  callback = function(ev)
    vim.bo[ev.buf].filetype = 'cypher'
  end,
})