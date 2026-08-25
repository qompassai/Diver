-- #################################################################
-- /qompassai/lua/diver/utils/ux/transparency.lua
-- Qompass AI Diver Transparency Utility
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
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
local M = {}

local augroup = vim.api.nvim_create_augroup('UtilsTransparency', { clear = true })

local default = {
  auto = true,
  groups = {
    'Comment',
    'Conditional',
    'Constant',
    'CursorLine',
    'CursorLineNr',
    'EndOfBuffer',
    'FloatBorder',
    'FoldColumn',
    'Function',
    'Identifier',
    'LineNr',
    'NonText',
    'Normal',
    'NormalFloat',
    'NormalNC',
    'Operator',
    'Pmenu',
    'PreProc',
    'Repeat',
    'SignColumn',
    'Special',
    'Statement',
    'StatusLine',
    'StatusLineNC',
    'String',
    'Structure',
    'Todo',
    'Type',
    'Underlined',
    'VertSplit',
  },
  extra_groups = {},
  excludes = {},
  keymaps = {
    toggle = '<leader>ut',
    enable = '<leader>uT',
    disable = '<leader>ub',
  },
}
M.config = vim.deepcopy(default)
M.state = {
  enabled = true,
}
local function considerable(name)
  if vim.tbl_contains(M.config.excludes, name) then
    return false
  end
  if vim.tbl_contains(M.config.groups, name) then
    return true
  end
  if vim.tbl_contains(M.config.extra_groups, name) then
    return true
  end
  return false
end
local function clear_backgrounds()
  if not M.state.enabled then
    return
  end
  for name, attrs in pairs(vim.api.nvim_get_hl(0, {})) do
    if considerable(name) and (attrs.bg or attrs.ctermbg) then
      local new_attr = vim.tbl_extend('force', attrs, {
        bg = 'NONE',
        ctermbg = 'NONE',
      })
      vim.api.nvim_set_hl(0, name, new_attr)
    end
  end
end
function M.enable()
  if M.state.enabled then
    return
  end
  M.state.enabled = true
  clear_backgrounds()
end
function M.disable()
  if not M.state.enabled then
    return
  end
  M.state.enabled = false
  if vim.g.colors_name then
    vim.cmd('colorscheme ' .. vim.g.colors_name)
  end
end
function M.toggle()
  if M.state.enabled then
    M.disable()
  else
    M.enable()
  end
end
local function set_keymaps()
  local km = M.config.keymaps or {}
  if km.toggle then
    vim.keymap.set('n', km.toggle, M.toggle, {
      desc = 'Toggle transparency',
    })
  end
  if km.enable then
    vim.keymap.set('n', km.enable, M.enable, {
      desc = 'Enable transparency',
    })
  end
  if km.disable then
    vim.keymap.set('n', km.disable, M.disable, {
      desc = 'Disable transparency',
    })
  end
end

local function set_commands()
  vim.api.nvim_create_user_command('TransparentEnable', M.enable, {})
  vim.api.nvim_create_user_command('TransparentDisable', M.disable, {})
  vim.api.nvim_create_user_command('TransparentToggle', M.toggle, {})
end
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(default), opts or {})

  set_commands()
  set_keymaps()

  if M.config.auto then
    vim.api.nvim_create_autocmd({
      'UIEnter',
      'ColorScheme',
    }, {
      group = augroup,
      desc = 'Clear background colors',
      callback = clear_backgrounds,
    })
    clear_backgrounds()
  end
end

return M
