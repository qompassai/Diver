-- #################################################################
-- ~/.config/nvim/lua/dap/apex.lua
-- Qompass AI Diver Native Salesforce Apex Debug Adapter Configuration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/forcedotcom/salesforcedx-vscode
---@source https://github.com/forcedotcom/salesforcedx-vscode/tree/develop/packages/salesforcedx-vscode-apex-replay-debugger
---@source https://github.com/forcedotcom/salesforcedx-vscode/tree/develop/packages/salesforcedx-vscode-apex-debugger

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'apex-dap'

---@type string[]
local ROOT_MARKERS = {
  'sfdx-project.json',
  '.sf',
  '.sfdx',
  '.git',
}

---@type string[]
local REPLAY_ADAPTER_RELATIVE_PATHS = {
  'packages/salesforcedx-vscode-apex-replay-debugger/dist/apexReplayDebug.js',
  'salesforcedx-vscode-apex-replay-debugger/dist/apexReplayDebug.js',
  'dist/apexReplayDebug.js',
}

---@type string[]
local INTERACTIVE_ADAPTER_RELATIVE_PATHS = {
  'packages/salesforcedx-vscode-apex-debugger/dist/apexDebug.js',
  'salesforcedx-vscode-apex-debugger/dist/apexDebug.js',
  'dist/apexDebug.js',
}

---@type string[]
local VSCODE_EXTENSION_ROOTS = {
  fs.joinpath(fn.expand('~'), '.vscode', 'extensions'),

  fs.joinpath(fn.expand('~'), '.vscode-oss', 'extensions'),

  fs.joinpath(fn.expand('~'), '.var', 'app', 'com.visualstudio.code', 'data', 'vscode', 'extensions'),
}

---@class ApexDapState
---@field interactive_adapter string?
---@field replay_adapter string?
---@field last_log string?
---@field root string?
local state = {
  interactive_adapter = nil,
  last_log = nil,
  replay_adapter = nil,
  root = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(('[%s] %s'):format(SOURCE, message), level or levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == 'string' and value ~= ''
end

---@param path string
---@return boolean
local function exists(path)
  if not nonempty_string(path) then
    return false
  end

  return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function readable_file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(path, ':p'))
end

---@param command string
---@return string?
local function executable_path(command)
  local path = fn.exepath(command)

  if not nonempty_string(path) then
    return nil
  end

  return fs.normalize(path)
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  local name = api.nvim_buf_get_name(bufnr)

  if name == '' then
    return ''
  end

  return normalize(name)
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local current_filename = filename(bufnr)

  if current_filename ~= '' then
    local detected = fs.root(current_filename, ROOT_MARKERS)

    if type(detected) == 'string' and detected ~= '' then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(current_filename)

    if type(parent) == 'string' and parent ~= '' then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(fn.getcwd())
end

---@param value string
---@return string
local function expand_path(value)
  return normalize(fn.expand(value))
end

---@param root string
---@param relative_paths string[]
---@return string?
local function adapter_from_root(root, relative_paths)
  if not directory(root) then
    return nil
  end

  for _, relative in ipairs(relative_paths) do
    local candidate = fs.joinpath(root, relative)

    if readable_file(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param prefix string
---@param adapter_file string
---@return string?
local function adapter_from_extension_directory(prefix, adapter_file)
  if not directory(prefix) then
    return nil
  end

  local handle = uv.fs_scandir(prefix)

  if handle == nil then
    return nil
  end

  ---@type string[]
  local matches = {}

  while true do
    local name, entry_type = uv.fs_scandir_next(handle)

    if name == nil then
      break
    end

    if entry_type == 'directory' and name:match('^salesforce%.salesforcedx%-vscode%-') then
      matches[#matches + 1] = name
    end
  end

  table.sort(matches, function(left, right)
    return left > right
  end)

  for _, name in ipairs(matches) do
    local candidate = fs.joinpath(prefix, name, 'dist', adapter_file)

    if readable_file(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param adapter_file string
---@return string?
local function adapter_from_vscode_install(adapter_file)
  for _, root in ipairs(VSCODE_EXTENSION_ROOTS) do
    local candidate = adapter_from_extension_directory(root, adapter_file)

    if candidate ~= nil then
      return candidate
    end
  end

  return nil
end

---@param env_name string
---@param relative_paths string[]
---@param adapter_file string
---@return string?
local function resolve_adapter(env_name, relative_paths, adapter_file)
  local configured = vim.env[env_name]

  if nonempty_string(configured) then
    local candidate = expand_path(configured)

    if readable_file(candidate) then
      return candidate
    end

    if directory(candidate) then
      local nested = adapter_from_root(candidate, relative_paths)

      if nested ~= nil then
        return nested
      end
    end

    notify(('%s does not resolve to a usable adapter: %s'):format(env_name, candidate), levels.WARN)
  end

  local salesforce_root = vim.env.NVIM_SALESFORCE_DAP_ROOT

  if nonempty_string(salesforce_root) then
    local candidate = adapter_from_root(expand_path(salesforce_root), relative_paths)

    if candidate ~= nil then
      return candidate
    end
  end

  return adapter_from_vscode_install(adapter_file)
end

---@return string?
local function replay_adapter()
  if state.replay_adapter ~= nil and readable_file(state.replay_adapter) then
    return state.replay_adapter
  end

  state.replay_adapter =
    resolve_adapter('NVIM_APEX_REPLAY_ADAPTER', REPLAY_ADAPTER_RELATIVE_PATHS, 'apexReplayDebug.js')

  return state.replay_adapter
end

---@return string?
local function interactive_adapter()
  if state.interactive_adapter ~= nil and readable_file(state.interactive_adapter) then
    return state.interactive_adapter
  end

  state.interactive_adapter =
    resolve_adapter('NVIM_APEX_INTERACTIVE_ADAPTER', INTERACTIVE_ADAPTER_RELATIVE_PATHS, 'apexDebug.js')

  return state.interactive_adapter
end

---@return string
local function node()
  return executable_path('node') or 'node'
end

---@param path string?
---@param description string
---@return string
local function required_adapter(path, description)
  if path ~= nil then
    return path
  end

  notify(('%s adapter was not found'):format(description), levels.ERROR)

  return '/nonexistent/qompass-apex-dap-adapter.js'
end

---@return string
local function debug_root()
  local root = project_root()

  state.root = root

  return root
end

---@return string?
local function choose_log_file()
  local default = state.last_log

  if default == nil then
    local root = project_root()

    default = fs.joinpath(root, '.sfdx', 'tools', 'debug', 'logs')

    if not exists(default) then
      default = root
    end
  end

  local selected = fn.input('Apex debug log: ', default, 'file')

  if selected == '' then
    return nil
  end

  selected = expand_path(selected)

  if not readable_file(selected) then
    notify(('debug log does not exist: %s'):format(selected), levels.ERROR)

    return nil
  end

  state.last_log = selected

  return selected
end

---@return string
local function replay_log()
  local selected = choose_log_file()

  if selected ~= nil then
    return selected
  end

  return ''
end

---@return string[]
local function prompt_user_ids()
  local input = fn.input('Apex debugger user IDs (comma-separated): ')

  if input == '' then
    return {}
  end

  ---@type string[]
  local result = {}

  for item in input:gmatch('[^,]+') do
    local value = vim.trim(item)

    if value ~= '' then
      result[#result + 1] = value
    end
  end

  return result
end

---@type table<string, boolean>
local VALID_REQUEST_TYPES = {
  BATCH_APEX = true,
  EXECUTE_ANONYMOUS = true,
  FUTURE = true,
  INBOUND_EMAIL_SERVICE = true,
  INVOCABLE_ACTION = true,
  LIGHTNING = true,
  QUEUEABLE = true,
  QUICK_ACTION = true,
  REMOTE_ACTION = true,
  REST = true,
  RUN_TESTS_ASYNCHRONOUS = true,
  RUN_TESTS_DEPLOY = true,
  RUN_TESTS_SYNCHRONOUS = true,
  SCHEDULED = true,
  SOAP = true,
  SYNCHRONOUS = true,
  VISUALFORCE = true,
}

---@return string[]
local function prompt_request_types()
  local input = fn.input('Apex request types (comma-separated, blank=all): ')

  if input == '' then
    return {}
  end

  ---@type string[]
  local result = {}

  for item in input:gmatch('[^,]+') do
    local value = vim.trim(item):upper()

    if VALID_REQUEST_TYPES[value] then
      result[#result + 1] = value
    else
      notify(('ignoring invalid Apex request type: %s'):format(value), levels.WARN)
    end
  end

  return result
end

---@return string
local function prompt_entry_point()
  return fn.input('Apex entry-point filter: ')
end

---@return string
local function salesforce_project()
  return debug_root()
end

---@return string
local function prompt_connect_type()
  local selected = fn.inputlist({
    'Apex debugger connection:',
    '1. Default / scratch-org debugger',
    '2. ISV Customer Debugger',
  })

  if selected == 2 then
    return 'ISV_DEBUGGER'
  end

  return 'DEFAULT'
end

---@return vim.SystemCompleted?
local function run_sf(arguments)
  local sf = executable_path('sf')

  if sf == nil then
    notify('Salesforce CLI `sf` is not installed or is not in PATH', levels.ERROR)

    return nil
  end

  local command = {
    sf,
  }

  vim.list_extend(command, arguments)

  local ok, result = pcall(function()
    return vim
      .system(command, {
        cwd = project_root(),
        text = true,
      })
      :wait()
  end)

  if not ok then
    notify(('Salesforce CLI invocation failed: %s'):format(tostring(result)), levels.ERROR)

    return nil
  end

  return result
end

local function show_sf_orgs()
  local result = run_sf({
    'org',
    'list',
    '--all',
  })

  if result == nil then
    return
  end

  local output = result.stdout or ''

  if output == '' then
    output = result.stderr or ''
  end

  if output == '' then
    output = 'Salesforce CLI returned no org information'
  end

  notify(output, result.code == 0 and levels.INFO or levels.ERROR)
end

local function show_status()
  local replay = replay_adapter()
  local interactive = interactive_adapter()
  local node_path = executable_path('node')
  local sf_path = executable_path('sf')

  notify(
    table.concat({
      'root: ' .. project_root(),

      'node: ' .. (node_path or 'not found'),

      'sf: ' .. (sf_path or 'not found'),

      'replay adapter: ' .. (replay or 'not found'),

      'interactive adapter: ' .. (interactive or 'not found'),

      'last replay log: ' .. (state.last_log or 'none'),
    }, '\n'),
    (node_path ~= nil and replay ~= nil) and levels.INFO or levels.WARN
  )
end

local function clear_cached_adapters()
  state.interactive_adapter = nil
  state.replay_adapter = nil

  notify('Salesforce adapter path cache cleared')
end

local function select_replay_adapter()
  local current = replay_adapter() or ''

  local selected = fn.input('Apex Replay adapter: ', current, 'file')

  if selected == '' then
    return
  end

  selected = expand_path(selected)

  if not readable_file(selected) then
    notify(('not a readable adapter: %s'):format(selected), levels.ERROR)

    return
  end

  state.replay_adapter = selected

  if type(M.adapters) == 'table' and type(M.adapters['apex-replay']) == 'table' then
    M.adapters['apex-replay'].args = {
      selected,
    }
  end

  notify(('Apex Replay adapter: %s'):format(selected))
end

local function select_interactive_adapter()
  local current = interactive_adapter() or ''

  local selected = fn.input('Apex Interactive adapter: ', current, 'file')

  if selected == '' then
    return
  end

  selected = expand_path(selected)

  if not readable_file(selected) then
    notify(('not a readable adapter: %s'):format(selected), levels.ERROR)

    return
  end

  state.interactive_adapter = selected

  if type(M.adapters) == 'table' and type(M.adapters.apex) == 'table' then
    M.adapters.apex.args = {
      selected,
    }
  end

  notify(('Apex Interactive adapter: %s'):format(selected))
end

---@type table<string, table>
M.adapters = {
  ['apex-replay'] = {
    name = 'apex-replay',

    type = 'executable',

    command = node(),

    args = {
      required_adapter(replay_adapter(), 'Apex Replay'),
    },

    options = {
      source_filetype = 'apex',
    },
  },

  apex = {
    name = 'apex',

    type = 'executable',

    command = node(),

    args = {
      required_adapter(interactive_adapter(), 'Apex Interactive'),
    },

    options = {
      source_filetype = 'apex',
    },
  },
}

---@type table<string, table[]>
M.configurations = {
  apex = {
    {
      name = 'Apex: Replay Debug Log',

      type = 'apex-replay',

      request = 'launch',

      logFile = replay_log,

      stopOnEntry = true,

      trace = false,
    },

    {
      name = 'Apex: Replay Debug Log (Trace)',

      type = 'apex-replay',

      request = 'launch',

      logFile = replay_log,

      stopOnEntry = true,

      trace = true,
    },

    {
      name = 'Apex: Interactive Debugger',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = {},

      requestTypeFilter = {},

      entryPointFilter = '',

      connectType = 'DEFAULT',

      trace = false,
    },

    {
      name = 'Apex: Interactive Debugger with Filters',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = prompt_user_ids,

      requestTypeFilter = prompt_request_types,

      entryPointFilter = prompt_entry_point,

      connectType = 'DEFAULT',

      trace = false,
    },

    {
      name = 'Apex: Interactive Debugger (ISV)',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = prompt_user_ids,

      requestTypeFilter = prompt_request_types,

      entryPointFilter = prompt_entry_point,

      connectType = 'ISV_DEBUGGER',

      trace = false,
    },

    {
      name = 'Apex: Interactive Debugger (Choose Mode)',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = prompt_user_ids,

      requestTypeFilter = prompt_request_types,

      entryPointFilter = prompt_entry_point,

      connectType = prompt_connect_type,

      trace = false,
    },

    {
      name = 'Apex: Interactive Debugger (Trace)',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = {},

      requestTypeFilter = {},

      entryPointFilter = '',

      connectType = 'DEFAULT',

      trace = true,
    },
  },

  ['apex-anon'] = {
    {
      name = 'Apex: Replay Debug Log',

      type = 'apex-replay',

      request = 'launch',

      logFile = replay_log,

      stopOnEntry = true,

      trace = false,
    },

    {
      name = 'Apex: Interactive Debugger',

      type = 'apex',

      request = 'launch',

      salesforceProject = salesforce_project,

      userIdFilter = {},

      requestTypeFilter = {
        'EXECUTE_ANONYMOUS',
      },

      entryPointFilter = '',

      connectType = 'DEFAULT',

      trace = false,
    },
  },
}

---@type table<string, DebugCommand>
M.commands = {
  ApexDebugAdaptersClear = {
    callback = function()
      clear_cached_adapters()
    end,

    desc = 'Clear Apex debug adapter path cache',
  },

  ApexDebugInteractiveAdapter = {
    callback = function()
      select_interactive_adapter()
    end,

    desc = 'Select Apex Interactive debug adapter',
  },

  ApexDebugLog = {
    callback = function()
      local selected = choose_log_file()

      if selected ~= nil then
        notify(('Apex replay log: %s'):format(selected))
      end
    end,

    desc = 'Select Apex Replay debug log',
  },

  ApexDebugOrgs = {
    callback = function()
      show_sf_orgs()
    end,

    desc = 'Show Salesforce orgs',
  },

  ApexDebugReplayAdapter = {
    callback = function()
      select_replay_adapter()
    end,

    desc = 'Select Apex Replay debug adapter',
  },

  ApexDebugStatus = {
    callback = function()
      show_status()
    end,

    desc = 'Show Apex debugger status',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  apex_debug_log = {
    lhs = '<leader>dAl',

    mode = 'n',

    rhs = function()
      local selected = choose_log_file()

      if selected ~= nil then
        notify(('Apex replay log: %s'):format(selected))
      end
    end,

    desc = 'Debug Apex: Select replay log',
  },

  apex_debug_orgs = {
    lhs = '<leader>dAo',

    mode = 'n',

    rhs = function()
      show_sf_orgs()
    end,

    desc = 'Debug Apex: Salesforce orgs',
  },

  apex_debug_status = {
    lhs = '<leader>dAs',

    mode = 'n',

    rhs = function()
      show_status()
    end,

    desc = 'Debug Apex: Status',
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root = nonempty_string(opts.root) and fs.normalize(opts.root) or project_root()

  local node_path = executable_path('node')

  if node_path == nil then
    vim.schedule(function()
      notify('Node.js is required to launch Salesforce Apex debug adapters', levels.ERROR)
    end)

    return
  end

  M.adapters['apex-replay'].command = node_path

  M.adapters.apex.command = node_path

  local replay = replay_adapter()

  if replay ~= nil then
    M.adapters['apex-replay'].args = {
      replay,
    }
  end

  local interactive = interactive_adapter()

  if interactive ~= nil then
    M.adapters.apex.args = {
      interactive,
    }
  end

  if replay == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'Apex Replay adapter was not found.',
          '',
          'Set one of:',
          '  NVIM_APEX_REPLAY_ADAPTER=/path/to/apexReplayDebug.js',
          '  NVIM_SALESFORCE_DAP_ROOT=/path/to/salesforcedx-vscode',
        }, '\n'),
        levels.WARN
      )
    end)
  end

  if interactive == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'Apex Interactive adapter was not found.',
          '',
          'Set one of:',
          '  NVIM_APEX_INTERACTIVE_ADAPTER=/path/to/apexDebug.js',
          '  NVIM_SALESFORCE_DAP_ROOT=/path/to/salesforcedx-vscode',
        }, '\n'),
        levels.WARN
      )
    end)
  end
end

---@return string?
function M.replay_adapter()
  return replay_adapter()
end

---@return string?
function M.interactive_adapter()
  return interactive_adapter()
end

---@return string
function M.root()
  return project_root()
end

return M