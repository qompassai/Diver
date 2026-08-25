-- /qompassai/Diver/lua/config/lang/docker.lua
-- Qompass AI Diver Docker/Container Lang Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local header = require('utils.docs')
local group = api.nvim_create_augroup('Docker', {
  clear = true })
local function buf_is_empty()
  return api.nvim_buf_get_lines(0, 0, 1, false)[1] == ''
end
api.nvim_create_autocmd('BufNewFile', {
  group = group,
  pattern = {
    'Dockerfile',
    'Dockerfile.*',
    'Containerfile',
    'Containerfile.*',
    'compose.yml',
    'compose.yaml',
    'docker-compose.yml',
    'docker-compose.yaml',
  },
  callback = function()
    if not buf_is_empty() then
      return
    end
    local filepath = fn.expand('%:p')
    local hdr = header.make_header(filepath, '#')
    api.nvim_buf_set_lines(0, 0, 0, false, hdr)
    vim.cmd('normal! G')
  end,
})
return M