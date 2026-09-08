-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/output.lua
-- Qompass AI Games Shared Output
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
local api = vim.api
local levels = vim.log.levels
local uv = vim.uv or vim.uv

local M = {}

local OUTPUT_HEIGHT = 12
local TIMER_DELAY_MS = 1000
local TIMER_INTERVAL_MS = 1000
local PROGRESS_MAX_PERCENT = 90
local PROGRESS_PERCENT_PER_SECOND = 5

---@class GamesOutputState
---@field window integer?

---@class GamesOutputRunOptions
---@field cwd? string
---@field env? table<string, string>
---@field failure? string
---@field on_failure? fun(result: vim.SystemCompleted)
---@field on_success? fun(result: vim.SystemCompleted)
---@field show_output? boolean
---@field success? string

---@class GamesTaskProgress
---@field done fun(success: boolean, message: string)
---@field start fun(message: string)
---@field tick fun(percent: integer, message: string)

---@param message string
---@return string
local function error_message(message)
  assert(type(message) == 'string')

  local trimmed = vim.trim(message)

  if trimmed == '' then
    return 'Command failed without output.'
  end

  return trimmed
end

---@param value number
---@param minimum integer
---@param maximum integer
---@return integer
local function clamp_integer(value, minimum, maximum)
  assert(type(value) == 'number')
  assert(type(minimum) == 'number')
  assert(type(maximum) == 'number')
  assert(minimum <= maximum)

  local clamped = math.max(minimum, math.min(maximum, value))
  local result = math.floor(clamped)

  ---@cast result integer

  return result
end

---@param buffer integer
---@return boolean
local function valid_buffer(buffer)
  assert(type(buffer) == 'number')

  return api.nvim_buf_is_valid(buffer)
end

---@param command string[]
---@return boolean
local function valid_command(command)
  if type(command) ~= 'table' or #command == 0 then
    return false
  end

  for index = 1, #command do
    local argument = command[index]

    if type(argument) ~= 'string' or argument == '' then
      return false
    end
  end

  return true
end

---@param timer uv.uv_timer_t?
local function stop_timer(timer)
  if timer == nil then
    return
  end

  if timer:is_closing() then
    return
  end

  timer:stop()
  timer:close()
end

---@param filetype string
---@return table
function M.new(filetype)
  assert(type(filetype) == 'string' and filetype ~= '')

  local self = {}

  ---@type GamesOutputState
  local state = {
    window = nil,
  }

  local stderr_namespace = api.nvim_create_namespace('games-nvim-' .. filetype .. '-stderr')

  ---@return boolean
  function self.has_window()
    local window = state.window

    return window ~= nil and api.nvim_win_is_valid(window)
  end

  function self.close_window()
    local window = state.window

    if window ~= nil and api.nvim_win_is_valid(window) then
      api.nvim_win_close(window, true)
    end

    state.window = nil
  end

  ---@param buffer integer
  ---@param data string?
  ---@return integer start_line
  ---@return integer end_line
  function self.apply_to_window(buffer, data)
    assert(type(buffer) == 'number')

    if not valid_buffer(buffer) then
      return 0, -1
    end

    if type(data) ~= 'string' or data == '' then
      return 0, -1
    end

    ---@type string[]
    local lines = {}

    for line in data:gmatch('[^\n]+') do
      lines[#lines + 1] = line
    end

    if #lines == 0 then
      return 0, -1
    end

    local line_count = api.nvim_buf_line_count(buffer)

    api.nvim_set_option_value('modifiable', true, {
      buf = buffer,
    })

    api.nvim_buf_set_lines(buffer, line_count, line_count, false, lines)

    api.nvim_set_option_value('modifiable', false, {
      buf = buffer,
    })

    local window = state.window

    if window ~= nil and api.nvim_win_is_valid(window) then
      api.nvim_win_set_cursor(window, {
        line_count + #lines,
        0,
      })
    end

    return line_count, line_count + #lines - 1
  end

  ---@return integer
  function self.create_window()
    local previous_window = api.nvim_get_current_win()
    local buffer = api.nvim_create_buf(false, true)

    api.nvim_set_option_value('modifiable', false, {
      buf = buffer,
    })

    api.nvim_set_option_value('buftype', 'nofile', {
      buf = buffer,
    })

    api.nvim_set_option_value('bufhidden', 'wipe', {
      buf = buffer,
    })

    api.nvim_set_option_value('buflisted', false, {
      buf = buffer,
    })

    api.nvim_set_option_value('filetype', filetype, {
      buf = buffer,
    })

    self.close_window()

    local new_window = api.nvim_open_win(buffer, false, {
      height = OUTPUT_HEIGHT,
      split = 'below',
      style = 'minimal',
      width = vim.o.columns,
    })

    state.window = new_window

    api.nvim_set_option_value('number', false, {
      win = new_window,
    })

    api.nvim_set_option_value('relativenumber', false, {
      win = new_window,
    })

    api.nvim_set_option_value('signcolumn', 'no', {
      win = new_window,
    })

    api.nvim_set_option_value('winfixbuf', true, {
      win = new_window,
    })

    api.nvim_set_option_value('wrap', true, {
      win = new_window,
    })

    if api.nvim_win_is_valid(previous_window) then
      api.nvim_set_current_win(previous_window)
    end

    api.nvim_create_autocmd('WinClosed', {
      callback = function()
        state.window = nil
      end,
      once = true,
      pattern = tostring(new_window),
    })

    return buffer
  end

  ---@param buffer integer
  ---@return table
  function self.create_system_opts(buffer)
    assert(type(buffer) == 'number')
    assert(valid_buffer(buffer))

    return {
      stderr = vim.schedule_wrap(function(_, data)
        local start_line, end_line = self.apply_to_window(buffer, data)

        if end_line < start_line or not valid_buffer(buffer) then
          return
        end

        for line = start_line, end_line do
          api.nvim_buf_set_extmark(buffer, stderr_namespace, line, 0, {
            end_col = -1,
            hl_group = 'Error',
          })
        end
      end),
      stdout = vim.schedule_wrap(function(_, data)
        self.apply_to_window(buffer, data)
      end),
      text = true,
    }
  end

  ---@param title string
  ---@return GamesTaskProgress
  function self.create_task_progress(title)
    assert(type(title) == 'string' and title ~= '')

    local progress = {
      kind = 'progress',
      source = 'games-nvim',
      title = title,
    }

    ---@param status string
    ---@param percent integer
    ---@param message string
    ---@param replace boolean
    local function update(status, percent, message, replace)
      assert(type(status) == 'string' and status ~= '')
      assert(type(percent) == 'number')
      assert(type(message) == 'string')
      assert(type(replace) == 'boolean')

      progress.status = status
      progress.percent = clamp_integer(percent, 0, 100)

      api.nvim_echo({
        {
          message,
        },
      }, replace, progress)

      vim.cmd.redraw({
        bang = true,
      })
    end

    return {
      start = function(message)
        assert(type(message) == 'string')

        update('running', 0, message, true)
      end,
      tick = function(percent, message)
        assert(type(percent) == 'number')
        assert(type(message) == 'string')

        update('running', percent, message, false)
      end,
      done = function(success, message)
        assert(type(success) == 'boolean')
        assert(type(message) == 'string')

        update(success and 'success' or 'failed', 100, message, true)
      end,
    }
  end

  ---@param progress GamesTaskProgress
  ---@param message string
  ---@return uv.uv_timer_t?
  function self.start_progress_timer(progress, message)
    assert(type(progress) == 'table')
    assert(type(progress.start) == 'function')
    assert(type(progress.tick) == 'function')
    assert(type(message) == 'string' and message ~= '')

    progress.start(message)

    ---@type uv.uv_timer_t?
    local timer = uv.new_timer()

    if timer == nil then
      vim.notify('games-nvim: unable to create progress timer.', levels.WARN)
      return nil
    end

    local elapsed_seconds = 0
    local base_message = message:gsub('%.%.$', '')

    timer:start(
      TIMER_DELAY_MS,
      TIMER_INTERVAL_MS,
      vim.schedule_wrap(function()
        if timer:is_closing() then
          return
        end

        elapsed_seconds = elapsed_seconds + 1

        local percent = clamp_integer(elapsed_seconds * PROGRESS_PERCENT_PER_SECOND, 0, PROGRESS_MAX_PERCENT)

        progress.tick(percent, ('%s... %ds'):format(base_message, elapsed_seconds))
      end)
    )

    return timer
  end

  ---@param title string
  ---@param message string
  ---@param command string[]
  ---@param opts? GamesOutputRunOptions
  function self.run_with_progress(title, message, command, opts)
    assert(type(title) == 'string' and title ~= '')
    assert(type(message) == 'string' and message ~= '')

    if not valid_command(command) then
      vim.notify('games-nvim: refusing to run an empty or invalid command.', levels.ERROR)
      return
    end

    local options = opts or {}
    local progress = self.create_task_progress(title)
    local timer = self.start_progress_timer(progress, message)

    ---@type integer?
    local buffer = nil

    if options.show_output then
      buffer = self.create_window()
    end

    local system_options

    if buffer ~= nil then
      system_options = self.create_system_opts(buffer)
    else
      system_options = {
        text = true,
      }
    end

    if type(options.cwd) == 'string' and options.cwd ~= '' then
      system_options.cwd = options.cwd
    end

    if type(options.env) == 'table' then
      system_options.env = options.env
    end

    local process = vim.system(
      command,
      system_options,
      vim.schedule_wrap(function(result)
        stop_timer(timer)

        if result.code == 0 then
          progress.done(true, options.success or 'Done.')

          if type(options.on_success) == 'function' then
            options.on_success(result)
          end

          return
        end

        progress.done(false, options.failure or 'Failed.')

        vim.notify(error_message(result.stderr or result.stdout or ''), levels.ERROR)

        if type(options.on_failure) == 'function' then
          options.on_failure(result)
        end
      end)
    )

    if process == nil then
      stop_timer(timer)

      progress.done(false, options.failure or 'Failed to start command.')

      vim.notify('games-nvim: could not start command: ' .. table.concat(command, ' '), levels.ERROR)
    end
  end

  return self
end

return M
