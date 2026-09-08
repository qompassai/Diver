-- #################################################################
-- /qompassai/lua/utils/dev/android/output.lua
-- Qompass AI Output
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
-- #################################################################
-- /qompassai/utils/dev/android/output.lua
-- Qompass AI Android Output
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
local M = {}
local api = vim.api
local config = require('utils.dev.android.config')
local window = nil
function M.get_window()
  return window
end

function M.has_window()
  return window ~= nil and api.nvim_win_is_valid(window)
end

function M.close_build_window()
  if M.has_window() then
    api.nvim_win_close(window, true)
  end

  window = nil
end

function M.apply_to_window(buf, data)
  if window == nil or data == nil then
    return 0, 0
  end

  local result = {}
  for line in data:gmatch('[^\n]+') do
    result[#result + 1] = line
  end

  if #result == 0 then
    return 0, 0
  end

  local buffer_lines = api.nvim_buf_line_count(buf) or 0

  api.nvim_set_option_value('modifiable', true, { buf = buf })
  api.nvim_buf_set_lines(buf, buffer_lines, buffer_lines, false, result)
  api.nvim_set_option_value('modifiable', false, { buf = buf })

  if M.has_window() then
    api.nvim_win_set_cursor(window, { buffer_lines + #result, 0 })
  end

  return buffer_lines, (buffer_lines + #result - 1)
end

function M.create_task_progress(title)
  local progress = {
    kind = 'progress',
    source = 'android-nvim',
    title = title,
  }

  local function update(status, percent, message, replace)
    progress.status = status
    progress.percent = percent
    api.nvim_echo({ { message } }, replace, progress)
    vim.cmd.redraw({ bang = true })
  end

  return {
    start = function(message)
      update('running', 0, message, true)
    end,

    tick = function(percent, message)
      update('running', percent, message, false)
    end,

    done = function(success, message)
      update(success and 'success' or 'failed', 100, message, true)
    end,
  }
end

function M.start_progress_timer(progress, message)
  progress.start(message)

  local time_passed = 0
  local base_message = message:gsub('%.%.$', '')
  local timer = vim.uv.new_timer()

  timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      time_passed = time_passed + 1
      local percent = math.min(90, time_passed * 5)
      progress.tick(percent, ('%s... %ds'):format(base_message, time_passed))
    end)
  )

  return timer
end

function M.create_gradle_system_opts(buf)
  return {
    text = true,

    stdout = vim.schedule_wrap(function(_, data)
      M.apply_to_window(buf, data)
    end),
    stderr = vim.schedule_wrap(function(_, data)
      local start_line, end_line = M.apply_to_window(buf, data)
      if end_line < start_line then
        return
      end
      for line = start_line, end_line do
        api.nvim_buf_set_extmark(buf, config.stderr_ns, line, 0, {
          end_col = -1,
          hl_group = 'Error',
        })
      end
    end),
  }
end

function M.create_build_window()
  local previous_win = api.nvim_get_current_win()
  local buf = api.nvim_create_buf(false, true)

  api.nvim_set_option_value('modifiable', false, { buf = buf })
  api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  api.nvim_set_option_value('buflisted', false, { buf = buf })

  vim.bo[buf].filetype = config.output_filetype

  if M.has_window() then
    api.nvim_win_close(window, true)
  end

  window = api.nvim_open_win(buf, false, {
    split = 'below',
    width = vim.o.columns,
    height = 10,
    style = 'minimal',
  })

  vim.wo[window].winfixbuf = true
  vim.wo[window].number = false
  vim.wo[window].relativenumber = false
  vim.wo[window].signcolumn = 'no'
  vim.wo[window].wrap = true

  if api.nvim_win_is_valid(previous_win) then
    api.nvim_set_current_win(previous_win)
  end

  api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(window),
    once = true,
    callback = function()
      window = nil
    end,
  })

  return buf
end

return M
