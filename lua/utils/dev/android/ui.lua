-- #################################################################
-- /qompassai/lua/utils/dev/android/ui.lua
-- Qompass AI Ui
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
local api = vim.api
local map = vim.keymap.set
local config = require('utils.dev.android.config')
local recent = require('utils.dev.android.recent')
local util = require('utils.dev.android.util')
function M.select_modal(items, opts, on_choice)
  vim.validate('items', items, 'table')
  vim.validate('on_choice', on_choice, 'function')
  opts = opts or {}
  if #items == 0 then
    on_choice(nil, nil)
    return
  end
  local format_item = opts.format_item or tostring
  local title = opts.prompt or 'Select one of:'
  local buf = api.nvim_create_buf(false, true)
  local lines = {}
  local max_width = vim.fn.strdisplaywidth(title)
  for i = 1, #items do
    local line = format_item(items[i])
    lines[#lines + 1] = line
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  local width = math.min(math.max(max_width + 2, vim.fn.strdisplaywidth(title) + 2), math.floor(vim.o.columns * 0.8))
  local height = math.min(#items, math.floor(vim.o.lines * 0.6))
  local border = vim.o.winborder ~= '' and vim.o.winborder or 'rounded'
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = border,
    title = title,
  })
  vim.wo[win].winfixbuf = true
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  local done = false
  local function finish(choice, idx)
    if done then
      return
    end
    done = true
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    on_choice(choice, idx)
  end
  local function go_back()
    if done then
      return
    end
    done = true
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    if opts.on_back then
      opts.on_back()
    else
      on_choice(nil, nil)
    end
  end
  local keymap_opts = {
    buffer = buf,
    nowait = true,
    silent = true,
  }
  map('n', '<CR>', function()
    local idx = api.nvim_win_get_cursor(win)[1]
    finish(items[idx], idx)
  end, keymap_opts)
  map('n', '<Esc>', go_back, keymap_opts)
  map('n', 'q', go_back, keymap_opts)
  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      if not done then
        finish(nil, nil)
      end
    end,
  })
end
function M.actions_for_group(actions, group)
  local grouped = {}
  for i = 1, #actions do
    local action = actions[i]
    if action.group == group then
      grouped[#grouped + 1] = action
    end
  end
  return grouped
end
function M.action_matches(action, search_query)
  if search_query == '' then
    return true
  end
  local haystack = (action.label .. ' ' .. action.group .. ' ' .. (action.keywords or '')):lower()
  return haystack:find(search_query, 1, true) ~= nil
end

function M.ensure_menu_highlights()
  local ok, normal = pcall(api.nvim_get_hl, 0, {
    name = 'Normal',
    link = false,
  })

  local bg = ok and normal.bg or 'NONE'

  api.nvim_set_hl(0, 'AndroidNvimMenuHeader', {
    fg = '#888899',
    bg = bg,
    bold = true,
  })

  api.nvim_set_hl(0, 'AndroidNvimMenuRecent', {
    fg = '#b0b0c0',
    bg = bg,
    blend = 25,
  })

  api.nvim_set_hl(0, 'AndroidNvimMenuGroup', {
    fg = '#d0d0e0',
    bg = bg,
  })
end

function M.show_group_menu(group, actions, run_action, show_root)
  local group_actions = M.actions_for_group(actions, group)
  if #group_actions == 0 then
    vim.notify('No actions in ' .. group .. '.', vim.log.levels.WARN, {})
    show_root()
    return
  end

  M.select_modal(group_actions, {
    prompt = group,
    format_item = function(action)
      return action.label
    end,
    on_back = show_root,
  }, function(choice)
    if choice then
      run_action(choice)
    end
  end)
end

function M.select_root_menu(actions, run_action)
  M.ensure_menu_highlights()
  local action_by_id = {}
  for i = 1, #actions do
    local action = actions[i]
    action_by_id[action.id] = action
  end

  local recent_ids = recent.load_recent_action_ids()
  local query = ''
  local selectable = {}
  local row_to_index = {}
  local done = false
  local width = math.min(72, math.floor(vim.o.columns * 0.85))
  local list_start_row = 3

  local function show_root()
    M.select_root_menu(actions, run_action)
  end

  local function build_display(search_query)
    search_query = util.trim(search_query):lower()

    local separator = string.rep('─', math.max(width - 2, 8))
    local result_lines = { separator }
    local highlights = {}
    local items = {}
    local row_map = {}
    local function buf_row()
      return 1 + #result_lines
    end
    local function add_header(label)
      result_lines[#result_lines + 1] = ' ' .. label
      highlights[#highlights + 1] = { buf_row(), 'AndroidNvimMenuHeader', 0, -1 }
    end
    local function add_item(text, entry, hl_group)
      result_lines[#result_lines + 1] = ' ' .. text
      local row = buf_row()
      items[#items + 1] = entry
      row_map[row] = #items

      if hl_group then
        highlights[#highlights + 1] = { row, hl_group, 0, -1 }
      end
    end
    if search_query ~= '' then
      for i = 1, #actions do
        local action = actions[i]
        if M.action_matches(action, search_query) then
          add_item(action.group .. ' ' .. action.label, {
            kind = 'action',
            action = action,
          })
        end
      end
      return result_lines, items, row_map, highlights
    end

    local recent_actions = {}
    for i = 1, #recent_ids do
      local action = action_by_id[recent_ids[i]]
      if action then
        recent_actions[#recent_actions + 1] = action
      end
    end

    if #recent_actions > 0 then
      add_header('Recent')
      for i = 1, #recent_actions do
        add_item(recent_actions[i].label, {
          kind = 'action',
          action = recent_actions[i],
        }, 'AndroidNvimMenuRecent')
      end
    end

    add_header('Browse')
    for i = 1, #config.group_order do
      local group = config.group_order[i]
      if #M.actions_for_group(actions, group) > 0 then
        add_item(group, {
          kind = 'group',
          group = group,
        }, 'AndroidNvimMenuGroup')
      end
    end

    return result_lines, items, row_map, highlights
  end

  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'android-nvim-actions'

  local border = vim.o.winborder ~= '' and vim.o.winborder or 'rounded'
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = 12,
    row = math.floor((vim.o.lines - 12) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = border,
    title = ' Android ',
  })

  vim.wo[win].winfixbuf = true
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false

  local function close_picker()
    if done then
      return
    end
    done = true
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end

  local function choose_entry(index)
    local entry = selectable[index]
    if not entry then
      return
    end

    if entry.kind == 'group' then
      close_picker()
      M.show_group_menu(entry.group, actions, run_action, show_root)
      return
    end

    run_action(entry.action)
    close_picker()
  end

  local function highlight_search_area(separator, section_highlights)
    api.nvim_buf_clear_namespace(buf, config.search_ns, 0, -1)

    api.nvim_buf_set_extmark(buf, config.search_ns, 0, 0, {
      end_col = -1,
      hl_group = 'Visual',
    })

    api.nvim_buf_set_extmark(buf, config.search_ns, 1, 0, {
      end_col = #separator,
      hl_group = 'Comment',
    })

    for i = 1, #section_highlights do
      local hl = section_highlights[i]
      api.nvim_buf_set_extmark(buf, config.search_ns, hl[1] - 1, hl[3], {
        end_col = hl[4],
        hl_group = hl[2],
      })
    end
  end
  local function first_selectable_row()
    local line_count = api.nvim_buf_line_count(buf)
    for row = list_start_row, line_count do
      if row_to_index[row] then
        return row
      end
    end
    return nil
  end
  local function refresh_results()
    local result_lines
    local section_highlights

    result_lines, selectable, row_to_index, section_highlights = build_display(query)

    if #selectable == 0 then
      result_lines[#result_lines + 1] = ' No matching actions'
    end

    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 1, -1, false, result_lines)
    highlight_search_area(result_lines[1], section_highlights)

    local height = math.min(math.max(#result_lines + (list_start_row - 1), 5), math.floor(vim.o.lines * 0.6))
    if api.nvim_win_is_valid(win) then
      api.nvim_win_set_config(win, { height = height })
    end
  end

  local function sync_query()
    query = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
    refresh_results()
  end

  local function go_to_search()
    api.nvim_win_set_cursor(win, { 1, #query })
    vim.cmd.startinsert()
  end

  local function go_to_first_entry()
    local row = first_selectable_row()
    if row == nil then
      return
    end

    vim.cmd.stopinsert()
    api.nvim_win_set_cursor(win, { row, 0 })
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
  refresh_results()
  api.nvim_win_set_cursor(win, { 1, 0 })

  local keymap_opts = {
    buffer = buf,
    nowait = true,
    silent = true,
  }

  map('i', '<Esc>', close_picker, keymap_opts)
  map('n', '<Esc>', close_picker, keymap_opts)
  map('n', 'q', close_picker, keymap_opts)
  map('i', '<Down>', go_to_first_entry, keymap_opts)

  local function move_cursor(delta)
    local row, col = unpack(api.nvim_win_get_cursor(win))
    local line_count = api.nvim_buf_line_count(buf)
    local target = row + delta

    while target >= list_start_row and target <= line_count do
      if row_to_index[target] then
        api.nvim_win_set_cursor(win, { target, col })
        return
      end
      target = target + delta
    end
  end

  map('n', 'j', function()
    local row = api.nvim_win_get_cursor(win)[1]
    if row < list_start_row then
      go_to_first_entry()
    else
      move_cursor(1)
    end
  end, keymap_opts)

  map('n', 'k', function()
    local row = api.nvim_win_get_cursor(win)[1]
    if row <= list_start_row then
      go_to_search()
    else
      move_cursor(-1)
    end
  end, keymap_opts)

  map('n', '<CR>', function()
    local row = api.nvim_win_get_cursor(win)[1]
    if row < list_start_row then
      go_to_search()
      return
    end

    local index = row_to_index[row]
    if index then
      choose_entry(index)
    end
  end, keymap_opts)

  api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
    buffer = buf,
    callback = function()
      if not done then
        sync_query()
      end
    end,
  })

  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      close_picker()
    end,
  })

  vim.cmd.startinsert()
end

return M
