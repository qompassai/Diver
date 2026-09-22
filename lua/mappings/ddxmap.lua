-- Filetype-aware debug actions; no nvim-dap, dap-python or dapui dependency.
-- SPDX-License-Identifier: Apache-2.0
local api = vim.api
local core = require('mappings._core')
local M = {}
local OWNER = 'ddxmap'
local CONFIGURATION_COUNT_MAX = 128
local NATIVE_FILETYPES = {
  ada = true,
  asm = true,
  c = true,
  cpp = true,
  cuda = true,
  fortran = true,
  rust = true,
  zig = true,
}
local options = {}
local group

local function backend(bufnr)
  local wrapper = options.wrapper or package.loaded.dap
  if type(wrapper) ~= 'table' or type(wrapper.registry) ~= 'function' or type(wrapper.backend) ~= 'function' then
    return nil, {}
  end
  local native = wrapper.backend()
  local registry = wrapper.registry()
  if type(native) ~= 'table' or type(registry) ~= 'table' or type(registry.configurations) ~= 'table' then
    return nil, {}
  end
  local configurations = registry.configurations[vim.bo[bufnr].filetype] or {}
  return native, configurations
end

local function start_native(bufnr)
  local native, configurations = backend(bufnr)
  local items = {}
  if native and type(native.run) == 'function' then
    for index = 1, math.min(#configurations, CONFIGURATION_COUNT_MAX) do
      local config = configurations[index]
      items[#items + 1] = {
        label = config.name or ('Configuration ' .. index),
        run = function()
          native.run(vim.deepcopy(config))
        end,
      }
    end
  end
  core.select(bufnr, items, 'Debug configurations: ' .. vim.bo[bufnr].filetype)
end

local function start_termdebug(bufnr)
  if vim.g.termdebug_is_running then
    core.notify('A Termdebug session is already running')
    return
  end
  local tick = api.nvim_buf_get_changedtick(bufnr)
  local filetype = vim.bo[bufnr].filetype
  vim.ui.input({ prompt = 'Executable for GDB: ', completion = 'file' }, function(path)
    if not path or path == '' then
      return
    end
    if
      not core.source(bufnr)
      or api.nvim_get_current_buf() ~= bufnr
      or vim.bo[bufnr].filetype ~= filetype
      or api.nvim_buf_get_changedtick(bufnr) ~= tick
    then
      core.notify('Buffer changed during selection; invoke debug again')
      return
    end
    path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
    if path:find('%z') or path:find('[\r\n]') or vim.fn.filereadable(path) ~= 1 then
      core.notify('Choose a readable executable')
      return
    end
    if vim.fn.exists(':Termdebug') ~= 2 then
      vim.cmd('packadd termdebug')
    end
    -- Structured Ex arguments, no shell interpolation of the selected path.
    api.nvim_cmd({ cmd = 'Termdebug', args = { path }, magic = { file = false } }, {})
  end)
end

local function available_actions(bufnr)
  local items = {}
  local native, configurations = backend(bufnr)
  if native and #configurations > 0 and type(native.run) == 'function' then
    items[#items + 1] = {
      key = 'r',
      label = 'Run filetype debug configuration',
      run = function()
        start_native(bufnr)
      end,
    }
    for _, action in ipairs({
      { 'b', 'Breakpoint', 'toggle_breakpoint' },
      { 'c', 'Continue', 'continue' },
      { 'i', 'Step into', 'step_into' },
      { 'n', 'Step over', 'step_over' },
      { 'o', 'Step out', 'step_out' },
      { 'p', 'Pause', 'pause' },
      { 'x', 'Terminate', 'terminate' },
    }) do
      if type(native[action[3]]) == 'function' then
        items[#items + 1] = { key = action[1], label = action[2], run = native[action[3]] }
      end
    end
    return items
  end
  if options.termdebug ~= false and NATIVE_FILETYPES[vim.bo[bufnr].filetype] and vim.fn.executable('gdb') == 1 then
    if not vim.g.termdebug_is_running then
      items[#items + 1] = {
        key = 'r',
        label = 'Start bundled Termdebug (GDB)',
        run = function()
          start_termdebug(bufnr)
        end,
      }
    else
      for _, action in ipairs({
        { 'b', 'Breakpoint', 'ToggleBreak' },
        { 'c', 'Continue', 'Continue' },
        { 'e', 'Evaluate cursor expression', 'Evaluate' },
        { 'i', 'Step into', 'Step' },
        { 'n', 'Step over', 'Over' },
        { 'o', 'Step out', 'Finish' },
        { 'p', 'Pause', 'Stop' },
      }) do
        if vim.fn.exists(':' .. action[3]) == 2 then
          items[#items + 1] = {
            key = action[1],
            label = action[2],
            run = core.command(action[3]),
          }
        end
      end
    end
  end
  return items
end

function M.actions(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  core.select(bufnr, available_actions(bufnr), 'Debug: ' .. vim.bo[bufnr].filetype)
end

local function attach(bufnr)
  local maps = {}
  if core.source(bufnr) then
    local items = available_actions(bufnr)
    if #items > 0 then
      maps[#maps + 1] = {
        lhs = '<LocalLeader>da',
        rhs = function()
          M.actions(bufnr)
        end,
        desc = 'Choose filetype debugger action',
      }
      for _, item in ipairs(items) do
        maps[#maps + 1] = {
          lhs = '<LocalLeader>d' .. item.key,
          rhs = function()
            -- Re-resolve the backend/session at invocation time.
            for _, current in ipairs(available_actions(bufnr)) do
              if current.key == item.key then
                current.run()
                return
              end
            end
            core.notify('Debug action is no longer available')
          end,
          desc = item.label,
        }
      end
    end
  end
  core.install(OWNER, bufnr, maps)
end

function M.teardown()
  core.teardown(OWNER)
  if group then
    api.nvim_del_augroup_by_id(group)
    group = nil
  end
end

function M.setup(opts)
  M.teardown()
  options = opts or {}
  core.watch(OWNER, attach, { 'BufEnter', 'FileType' })
  group = api.nvim_create_augroup('NativeMappings_debug_lifecycle', { clear = true })
  api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'TermdebugStartPost', 'TermdebugStopPost' },
    callback = function()
      for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if core.usable(bufnr) then
          attach(bufnr)
        end
      end
    end,
  })
end

M.setup_ddxmap = M.setup
return M
