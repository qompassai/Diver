#!/usr/bin/env -S nvim -l
-- testq.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local lang = arg[1] or 'tsx'
local query_path = vim.fn.expand('~/.config/nvim/queries/' .. lang .. '/context.scm')

if vim.fn.filereadable(query_path) == 0 then
  print('Error: Query file not found at ' .. query_path)
  os.exit(1)
end
local query_text = table.concat(vim.fn.readfile(query_path), '\n')
local ok, result = pcall(vim.treesitter.query.parse, lang, query_text)
if ok then
  print('✓ Query is valid for ' .. lang)
  print('File: ' .. query_path)
  os.exit(0)
else
  print('✗ Query error for ' .. lang .. ':')
  print(result)
  os.exit(1)
end
