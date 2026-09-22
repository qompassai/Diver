-- #################################################################
-- /qompassai/lua/mappings/refactormap.lua
-- Qompass AI Refactormap
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--

-- #################################################################
-- /qompassai/Diver/lua/mappings/refactormap.lua
-- Native refactor mappings
-- SPDX-License-Identifier: Apache-2.0
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

local map = vim.keymap.set
local refactor = require('refactor')

local silent = { silent = true }

map('x', '<leader>re', function()
  refactor.extract({ visual = true })
end, vim.tbl_extend('force', silent, { desc = 'Refactor: extract' }))

map('x', '<leader>rv', function()
  refactor.extract_var({ visual = true })
end, vim.tbl_extend('force', silent, { desc = 'Refactor: extract variable' }))

map('x', '<leader>rf', function()
  refactor.extract_func({ visual = true })
end, vim.tbl_extend('force', silent, { desc = 'Refactor: extract function' }))

map('n', '<leader>ri', refactor.inline, {
  silent = true,
  desc = 'Refactor: inline',
})

map('n', '<leader>rV', refactor.inline_var, {
  silent = true,
  desc = 'Refactor: inline variable',
})

map('n', '<leader>rF', refactor.inline_func, {
  silent = true,
  desc = 'Refactor: inline function',
})

map('n', '<leader>rr', refactor.rename, {
  silent = true,
  desc = 'Refactor: rename',
})

map('n', '<leader>ra', refactor.code_action, {
  silent = true,
  desc = 'Refactor: all semantic refactors',
})

map('n', '<leader>dl', refactor.print_loc, {
  silent = true,
  desc = 'Debug: print location',
})

map('n', '<leader>dv', refactor.print_var, {
  silent = true,
  desc = 'Debug: print variable',
})

map('x', '<leader>dv', function()
  refactor.print_var({ visual = true })
end, {
  silent = true,
  desc = 'Debug: print selected variables',
})

map('n', '<leader>de', refactor.print_exp, {
  silent = true,
  desc = 'Debug: print expression',
})

map('x', '<leader>de', function()
  refactor.print_exp({ visual = true })
end, {
  silent = true,
  desc = 'Debug: print selected expression',
})

map({ 'n', 'x' }, '<leader>dc', refactor.cleanup, {
  silent = true,
  desc = 'Debug: cleanup native print statements',
})

return {}
