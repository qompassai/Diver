-- #################################################################
-- /qompassai/Diver/lua/linters/update.lua
-- Qompass AI Linter Update Manager
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
local fn = vim.fn
local fs = vim.fs
local json = vim.json
local system = vim.system
local version = vim.version
local sort = table.sort
local type = type
local M = {}
local CHECK_INTERVAL_SECONDS = 24 * 60 * 60
local COMMAND_TIMEOUT_MS = 15000
local INSTALL_TIMEOUT_MS = 5 * 60 * 1000
local MAX_CONCURRENT = 4
local OUTPUT_LENGTH_MAX = 1024 * 1024
local state_dir = fs.joinpath(fn.stdpath('state'), 'qompassai')
local state_file = fs.joinpath(state_dir, 'linter-updates.json')
---@alias LinterPackageManager
---| 'cargo'
---| 'gem'
---| 'go'
---| 'npm'
---| 'pipx'
---| 'custom'

---@class LinterUpdateCommand
---@field cmd string[]
---@field parser? fun(stdout: string, stderr: string): string?

---@class LinterUpdateSpec
---@field manager LinterPackageManager
---@field package string
---@field executable? string
---@field module? string
---@field enabled? boolean
---@field locked? boolean
---@field current? LinterUpdateCommand
---@field latest? LinterUpdateCommand
---@field install? string[]
---@field update? string[]
---@field remove? string[]

---@class ManagedLinter
---@field cmd? string|string[]
---@field update? LinterUpdateSpec

---@class LinterUpdateState
---@field available boolean
---@field checked_at integer
---@field current? string
---@field error? string
---@field latest? string
---@field manager LinterPackageManager
---@field package string

---@class SystemResult
---@field code integer
---@field signal integer
---@field stdout string
---@field stderr string

---@class UpdateQueueEntry
---@field name string
---@field spec LinterUpdateSpec

---@type table<string, LinterUpdateState>
local state = {}

---@type table<string, ManagedLinter>
local linters = {}

---@param value string
---@return string
local function trim(value)
  return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

---@param value string
---@return string?
local function first_version(value)
  if value == '' then
    return nil
  end
  local found = value:match('[vV]?([0-9]+%.[0-9]+%.[0-9]+[%w%.%+%-]*)')
  if found ~= nil and found ~= '' then
    return found
  end
  found = value:match('[vV]?([0-9]+%.[0-9]+[%w%.%+%-]*)')
  if found ~= nil and found ~= '' then
    return found
  end
  return nil
end
---@param value string
---@return string
local function normalize_version(value)
  local normalized = trim(value)
  normalized = normalized:gsub('^[vV]', '')
  return normalized
end
---@param current string
---@param latest string
---@return boolean
local function newer(current, latest)
  local normalized_current = normalize_version(current)
  local normalized_latest = normalize_version(latest)
  if normalized_current == '' or normalized_latest == '' then
    return false
  end
  local current_version = version.parse(normalized_current, {
    strict = false,
  })
  local latest_version = version.parse(normalized_latest, {
    strict = false,
  })
  if current_version == nil or latest_version == nil then
    return normalized_current ~= normalized_latest
  end
  return version.gt(latest_version, current_version)
end
---@param path string
---@return string?
local function read_file(path)
  local handle = io.open(path, 'rb')

  if handle == nil then
    return nil
  end
  local data = handle:read('*a')
  handle:close()
  if type(data) ~= 'string' then
    return nil
  end
  if #data > OUTPUT_LENGTH_MAX then
    return nil
  end
  return data
end
---@param path string
---@param data string
---@return boolean
local function write_file(path, data)
  assert(path ~= '')
  if #data > OUTPUT_LENGTH_MAX then
    return false
  end
  local directory = fs.dirname(path)
  if type(directory) ~= 'string' or directory == '' then
    return false
  end
  fn.mkdir(directory, 'p')

  local temporary = path .. '.tmp'

  local handle = io.open(temporary, 'wb')
  if handle == nil then
    return false
  end
  local result = handle:write(data)
  handle:close()
  if result == nil then
    os.remove(temporary)

    return false
  end
  local renamed = os.rename(temporary, path)
  if renamed == nil then
    os.remove(temporary)

    return false
  end
  return true
end
local function load_state()
  local contents = read_file(state_file)

  if contents == nil or contents == '' then
    return
  end

  local ok, decoded = pcall(json.decode, contents)

  if not ok or type(decoded) ~= 'table' then
    return
  end

  ---@cast decoded table<string, LinterUpdateState>

  state = decoded
end
local function save_state()
  local ok, encoded = pcall(json.encode, state)
  if not ok or type(encoded) ~= 'string' then
    return
  end
  write_file(state_file, encoded)
end
---@param command string[]
---@param timeout integer
---@param callback fun(result: SystemResult)
local function execute(command, timeout, callback)
  assert(#command > 0)
  assert(timeout > 0)
  local ok, err = pcall(function()
    system(command, {
      text = true,
      timeout = timeout,
    }, function(result)
      local stdout = result.stdout
      local stderr = result.stderr
      if type(stdout) ~= 'string' then
        stdout = ''
      end
      if type(stderr) ~= 'string' then
        stderr = ''
      end
      if #stdout > OUTPUT_LENGTH_MAX then
        stdout = ''
      end
      if #stderr > OUTPUT_LENGTH_MAX then
        stderr = ''
      end
      ---@type SystemResult
      local completed = {
        code = result.code,
        signal = result.signal,
        stdout = stdout,
        stderr = stderr,
      }
      vim.schedule(function()
        callback(completed)
      end)
    end)
  end)
  if ok then
    return
  end
  local message = tostring(err)
  vim.schedule(function()
    callback({
      code = -1,
      signal = 0,
      stdout = '',
      stderr = message,
    })
  end)
end
---@param spec LinterUpdateSpec
---@return string
local function executable(spec)
  local value = spec.executable
  if type(value) == 'string' and value ~= '' then
    return value
  end
  return spec.package
end
---@param spec LinterUpdateSpec
---@return string[]
local function current_command(spec)
  local current = spec.current
  if current ~= nil then
    return current.cmd
  end
  return {
    executable(spec),
    '--version',
  }
end
---@param spec LinterUpdateSpec
---@param stdout string
---@param stderr string
---@return string?
local function parse_current(spec, stdout, stderr)
  local current = spec.current
  if current ~= nil and current.parser ~= nil then
    local parsed = current.parser(stdout, stderr)
    if type(parsed) == 'string' and parsed ~= '' then
      return parsed
    end
    return nil
  end
  local source
  if stdout ~= '' then
    source = stdout
  else
    source = stderr
  end
  return first_version(source)
end
---@param spec LinterUpdateSpec
---@return string[]
local function latest_command(spec)
  local latest = spec.latest

  if latest ~= nil then
    return latest.cmd
  end
  if spec.manager == 'cargo' then
    return {
      'cargo',
      'info',
      spec.package,
      '--color',
      'never',
    }
  end
  if spec.manager == 'npm' then
    return {
      'npm',
      'view',
      spec.package,
      'version',
      '--json',
    }
  end

  if spec.manager == 'pipx' then
    return {
      'python',
      '-m',
      'pip',
      'index',
      'versions',
      spec.package,
    }
  end

  if spec.manager == 'gem' then
    return {
      'gem',
      'search',
      '^' .. spec.package .. '$',
      '--remote',
      '--all',
    }
  end

  if spec.manager == 'go' then
    local module = spec.module

    assert(type(module) == 'string' and module ~= '', 'Go linter update spec requires `module`')

    return {
      'go',
      'list',
      '-m',
      '-json',
      module .. '@latest',
    }
  end

  error('Custom update spec requires `latest.cmd`')
end

---@param spec LinterUpdateSpec
---@param stdout string
---@param stderr string
---@return string?
local function parse_latest(spec, stdout, stderr)
  local latest = spec.latest

  if latest ~= nil and latest.parser ~= nil then
    local parsed = latest.parser(stdout, stderr)

    if type(parsed) == 'string' and parsed ~= '' then
      return parsed
    end

    return nil
  end

  if spec.manager == 'cargo' then
    local found = stdout:match('\nversion:%s*([%w%.%+%-]+)')

    if found == nil then
      found = stdout:match('^version:%s*([%w%.%+%-]+)')
    end

    if type(found) == 'string' and found ~= '' then
      return found
    end

    return nil
  end

  if spec.manager == 'npm' then
    local ok, decoded = pcall(json.decode, stdout)

    if ok and type(decoded) == 'string' and decoded ~= '' then
      return decoded
    end

    return first_version(stdout)
  end

  if spec.manager == 'pipx' then
    local found = stdout:match('Available versions:%s*([%w%.%+%-]+)')

    if type(found) == 'string' and found ~= '' then
      return found
    end

    return first_version(stdout)
  end

  if spec.manager == 'gem' then
    local versions = stdout:match('%(([^%)]+)%)')

    if type(versions) ~= 'string' or versions == '' then
      return first_version(stdout)
    end

    local first = versions:match('^%s*([^,%s]+)')

    if type(first) ~= 'string' or first == '' then
      return nil
    end

    return normalize_version(first)
  end

  if spec.manager == 'go' then
    local ok, decoded = pcall(json.decode, stdout)

    if not ok or type(decoded) ~= 'table' then
      return nil
    end

    local value = decoded.Version

    if type(value) ~= 'string' or value == '' then
      return nil
    end

    return normalize_version(value)
  end

  local source

  if stdout ~= '' then
    source = stdout
  else
    source = stderr
  end

  return first_version(source)
end

---@param spec LinterUpdateSpec
---@return string[]
local function install_command(spec)
  if spec.install ~= nil then
    return spec.install
  end

  if spec.manager == 'cargo' then
    local command = {
      'cargo',
      'install',
      spec.package,
    }

    if spec.locked ~= false then
      command[#command + 1] = '--locked'
    end

    return command
  end

  if spec.manager == 'npm' then
    return {
      'npm',
      'install',
      '--global',
      spec.package .. '@latest',
    }
  end

  if spec.manager == 'pipx' then
    return {
      'pipx',
      'install',
      spec.package,
    }
  end
  if spec.manager == 'gem' then
    return {
      'gem',
      'install',
      spec.package,
    }
  end
  if spec.manager == 'go' then
    return {
      'go',
      'install',
      spec.package .. '@latest',
    }
  end

  error('Custom package requires `install` command')
end

---@param spec LinterUpdateSpec
---@return string[]
local function update_command(spec)
  if spec.update ~= nil then
    return spec.update
  end

  if spec.manager == 'cargo' then
    local command = {
      'cargo',
      'install',
      spec.package,
    }

    if spec.locked ~= false then
      command[#command + 1] = '--locked'
    end

    return command
  end

  if spec.manager == 'npm' then
    return {
      'npm',
      'install',
      '--global',
      spec.package .. '@latest',
    }
  end
  if spec.manager == 'pipx' then
    return {
      'pipx',
      'upgrade',
      spec.package,
    }
  end
  if spec.manager == 'gem' then
    return {
      'gem',
      'update',
      spec.package,
    }
  end
  if spec.manager == 'go' then
    return {
      'go',
      'install',
      spec.package .. '@latest',
    }
  end

  error('Custom package requires `update` command')
end

---@param spec LinterUpdateSpec
---@return string[]?
local function remove_command(spec)
  if spec.remove ~= nil then
    return spec.remove
  end

  if spec.manager == 'cargo' then
    return {
      'cargo',
      'uninstall',
      spec.package,
    }
  end
  if spec.manager == 'npm' then
    return {
      'npm',
      'uninstall',
      '--global',
      spec.package,
    }
  end
  if spec.manager == 'pipx' then
    return {
      'pipx',
      'uninstall',
      spec.package,
    }
  end
  if spec.manager == 'gem' then
    return {
      'gem',
      'uninstall',
      spec.package,
    }
  end
  if spec.manager == 'go' then
    return nil
  end

  return nil
end
---@param name string
---@return ManagedLinter?
local function get_linter(name)
  return linters[name]
end

---@param name string
---@return LinterUpdateSpec?
local function get_spec(name)
  local linter = get_linter(name)

  if linter == nil then
    return nil
  end

  return linter.update
end

---@param name string
---@param spec LinterUpdateSpec
---@param callback fun()
local function check_one(name, spec, callback)
  local executable_name = executable(spec)

  if fn.executable(executable_name) ~= 1 then
    state[name] = {
      available = false,
      checked_at = os.time(),
      manager = spec.manager,
      package = spec.package,
      error = 'not installed',
    }

    callback()

    return
  end

  execute(current_command(spec), COMMAND_TIMEOUT_MS, function(current_result)
    if current_result.code ~= 0 then
      state[name] = {
        available = false,
        checked_at = os.time(),
        manager = spec.manager,
        package = spec.package,
        error = 'unable to determine installed version',
      }

      callback()

      return
    end

    local current = parse_current(spec, current_result.stdout, current_result.stderr)

    if type(current) ~= 'string' or current == '' then
      state[name] = {
        available = false,
        checked_at = os.time(),
        manager = spec.manager,
        package = spec.package,
        error = 'unable to parse installed version',
      }

      callback()

      return
    end

    local ok, command = pcall(latest_command, spec)

    if not ok or type(command) ~= 'table' then
      state[name] = {
        available = false,
        checked_at = os.time(),
        current = current,
        manager = spec.manager,
        package = spec.package,
        error = tostring(command),
      }

      callback()

      return
    end

    ---@cast command string[]

    execute(command, COMMAND_TIMEOUT_MS, function(latest_result)
      if latest_result.code ~= 0 then
        state[name] = {
          available = false,
          checked_at = os.time(),
          current = current,
          manager = spec.manager,
          package = spec.package,
          error = 'unable to query package registry',
        }

        callback()

        return
      end

      local latest = parse_latest(spec, latest_result.stdout, latest_result.stderr)

      if type(latest) ~= 'string' or latest == '' then
        state[name] = {
          available = false,
          checked_at = os.time(),
          current = current,
          manager = spec.manager,
          package = spec.package,
          error = 'unable to parse latest version',
        }

        callback()

        return
      end

      local normalized_current = normalize_version(current)

      local normalized_latest = normalize_version(latest)

      state[name] = {
        available = newer(normalized_current, normalized_latest),
        checked_at = os.time(),
        current = normalized_current,
        latest = normalized_latest,
        manager = spec.manager,
        package = spec.package,
      }

      callback()
    end)
  end)
end

---@return string[]
local function managed_names()
  local names = {}

  for name, linter in pairs(linters) do
    if linter.update ~= nil then
      names[#names + 1] = name
    end
  end

  sort(names)

  return names
end

---@return string[]
local function outdated_names()
  local names = {}

  for name, entry in pairs(state) do
    if entry.available then
      names[#names + 1] = name
    end
  end

  sort(names)

  return names
end

---@return string[]
local function missing_names()
  local names = {}

  for name, entry in pairs(state) do
    if entry.error == 'not installed' then
      names[#names + 1] = name
    end
  end

  sort(names)

  return names
end

---@return integer
function M.count()
  return #outdated_names()
end

---@return integer
function M.missing_count()
  return #missing_names()
end

---@return string
function M.statusline()
  local outdated = M.count()
  local missing = M.missing_count()

  if outdated == 0 and missing == 0 then
    return ''
  end

  if outdated > 0 and missing > 0 then
    return ('L↑%d L!%d'):format(outdated, missing)
  end

  if outdated > 0 then
    return ('L↑%d'):format(outdated)
  end

  return ('L!%d'):format(missing)
end

---@param name string
function M.install(name)
  local spec = get_spec(name)

  if spec == nil then
    vim.notify('No package metadata for linter: ' .. name, vim.log.levels.WARN)

    return
  end

  if fn.executable(executable(spec)) == 1 then
    vim.notify(name .. ' is already installed', vim.log.levels.INFO)

    return
  end

  local ok, command = pcall(install_command, spec)

  if not ok or type(command) ~= 'table' then
    vim.notify(tostring(command), vim.log.levels.ERROR)

    return
  end

  ---@cast command string[]

  vim.ui.select({
    'Install',
    'Cancel',
  }, {
    prompt = ('Install %s using %s?'):format(name, spec.manager),
  }, function(choice)
    if choice ~= 'Install' then
      return
    end

    execute(command, INSTALL_TIMEOUT_MS, function(result)
      if result.code ~= 0 then
        local message = result.stderr ~= '' and result.stderr or ('Failed to install ' .. name)

        vim.notify(message, vim.log.levels.ERROR)

        return
      end

      vim.notify(name .. ' installed', vim.log.levels.INFO)

      M.check_one(name)
    end)
  end)
end

---@param name string
function M.update(name)
  local spec = get_spec(name)

  if spec == nil then
    vim.notify('No package metadata for linter: ' .. name, vim.log.levels.WARN)

    return
  end

  if fn.executable(executable(spec)) ~= 1 then
    M.install(name)

    return
  end

  local ok, command = pcall(update_command, spec)

  if not ok or type(command) ~= 'table' then
    vim.notify(tostring(command), vim.log.levels.ERROR)

    return
  end

  ---@cast command string[]

  local entry = state[name]

  local current = '?'
  local latest = '?'

  if entry ~= nil then
    if type(entry.current) == 'string' and entry.current ~= '' then
      current = entry.current
    end

    if type(entry.latest) == 'string' and entry.latest ~= '' then
      latest = entry.latest
    end
  end

  vim.ui.select({
    'Update',
    'Cancel',
  }, {
    prompt = ('%s %s → %s using %s?'):format(name, current, latest, spec.manager),
  }, function(choice)
    if choice ~= 'Update' then
      return
    end

    execute(command, INSTALL_TIMEOUT_MS, function(result)
      if result.code ~= 0 then
        local message = result.stderr ~= '' and result.stderr or ('Failed to update ' .. name)

        vim.notify(message, vim.log.levels.ERROR)

        return
      end

      vim.notify(name .. ' updated', vim.log.levels.INFO)

      M.check_one(name)
    end)
  end)
end

---@param name string
function M.remove(name)
  local spec = get_spec(name)

  if spec == nil then
    vim.notify('No package metadata for linter: ' .. name, vim.log.levels.WARN)

    return
  end

  if fn.executable(executable(spec)) ~= 1 then
    vim.notify(name .. ' is not installed', vim.log.levels.INFO)

    return
  end

  local command = remove_command(spec)

  if command == nil then
    vim.notify(
      ('%s does not provide a safe ' .. 'package-aware remove operation ' .. 'for %s'):format(spec.manager, name),
      vim.log.levels.WARN
    )

    return
  end

  vim.ui.select({
    'Remove',
    'Cancel',
  }, {
    prompt = ('Remove %s using %s?'):format(name, spec.manager),
  }, function(choice)
    if choice ~= 'Remove' then
      return
    end

    execute(command, INSTALL_TIMEOUT_MS, function(result)
      if result.code ~= 0 then
        local message = result.stderr ~= '' and result.stderr or ('Failed to remove ' .. name)

        vim.notify(message, vim.log.levels.ERROR)

        return
      end

      state[name] = {
        available = false,
        checked_at = os.time(),
        manager = spec.manager,
        package = spec.package,
        error = 'not installed',
      }

      save_state()

      vim.notify(name .. ' removed', vim.log.levels.INFO)
    end)
  end)
end

---@param name string
function M.manage(name)
  local spec = get_spec(name)

  if spec == nil then
    vim.notify('No package metadata for linter: ' .. name, vim.log.levels.WARN)

    return
  end

  local installed = fn.executable(executable(spec)) == 1

  if not installed then
    M.install(name)

    return
  end

  local choices = {
    'Check',
    'Update',
  }

  if remove_command(spec) ~= nil then
    choices[#choices + 1] = 'Remove'
  end

  choices[#choices + 1] = 'Cancel'

  vim.ui.select(choices, {
    prompt = ('%s [%s]'):format(name, spec.manager),
  }, function(choice)
    if choice == 'Check' then
      M.check_one(name)
    elseif choice == 'Update' then
      M.update(name)
    elseif choice == 'Remove' then
      M.remove(name)
    end
  end)
end

---@param name string
function M.check_one(name)
  local spec = get_spec(name)

  if spec == nil then
    vim.notify('No update metadata for linter: ' .. name, vim.log.levels.WARN)

    return
  end

  check_one(name, spec, function()
    save_state()

    local entry = state[name]

    if entry == nil then
      return
    end

    if entry.error ~= nil then
      vim.notify(('%s: %s'):format(name, entry.error), vim.log.levels.WARN)

      return
    end

    if entry.available then
      local current = entry.current or '?'

      local latest = entry.latest or '?'

      vim.notify(('%s update available: ' .. '%s → %s'):format(name, current, latest), vim.log.levels.INFO)

      return
    end

    vim.notify(('%s is current (%s)'):format(name, entry.current or '?'), vim.log.levels.INFO)
  end)
end

---@param force? boolean
function M.check(force)
  ---@type UpdateQueueEntry[]
  local queue = {}

  local now = os.time()

  for name, linter in pairs(linters) do
    local spec = linter.update

    if spec ~= nil and spec.enabled ~= false then
      local previous = state[name]

      local stale = previous == nil or (now - previous.checked_at >= CHECK_INTERVAL_SECONDS)

      if force == true or stale then
        queue[#queue + 1] = {
          name = name,
          spec = spec,
        }
      end
    end
  end

  if #queue == 0 then
    return
  end

  sort(queue, function(left, right)
    return left.name < right.name
  end)

  local cursor = 1
  local running = 0
  local completed = 0
  local total = #queue

  ---@type fun()?
  local start_next

  start_next = function()
    while running < MAX_CONCURRENT and cursor <= total do
      local item = queue[cursor]

      cursor = cursor + 1
      running = running + 1

      check_one(item.name, item.spec, function()
        running = running - 1
        completed = completed + 1

        if completed >= total then
          save_state()

          local update_count = M.count()

          local missing_count = M.missing_count()

          if update_count > 0 or missing_count > 0 then
            vim.notify(
              ('Linter health: %d update%s, ' .. '%d missing'):format(
                update_count,
                update_count == 1 and '' or 's',
                missing_count
              ),
              vim.log.levels.INFO
            )
          end

          return
        end

        if start_next ~= nil then
          start_next()
        end
      end)
    end
  end

  start_next()
end

function M.select()
  local names = managed_names()

  if #names == 0 then
    vim.notify('No managed linters registered', vim.log.levels.INFO)

    return
  end

  vim.ui.select(names, {
    prompt = 'Manage linter',

    format_item = function(name)
      local spec = get_spec(name)
      local entry = state[name]

      if spec == nil then
        return name
      end

      if entry == nil then
        return ('%s [%s] unchecked'):format(name, spec.manager)
      end

      if entry.error == 'not installed' then
        return ('%s [%s] not installed'):format(name, spec.manager)
      end

      if entry.available then
        return ('%s [%s] %s → %s'):format(name, spec.manager, entry.current or '?', entry.latest or '?')
      end

      return ('%s [%s] %s'):format(name, spec.manager, entry.current or '?')
    end,
  }, function(name)
    if name ~= nil then
      M.manage(name)
    end
  end)
end

---@param registered table<string, ManagedLinter>
function M.setup(registered)
  assert(type(registered) == 'table')

  linters = registered

  load_state()

  api.nvim_create_user_command('LinterManage', function(opts)
    if opts.args == '' then
      M.select()

      return
    end

    M.manage(opts.args)
  end, {
    nargs = '?',
    complete = function()
      return managed_names()
    end,
    desc = 'Manage linter packages',
  })

  api.nvim_create_user_command('LinterInstall', function(opts)
    M.install(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return managed_names()
    end,
    desc = 'Install a linter',
  })

  api.nvim_create_user_command('LinterUpdate', function(opts)
    M.update(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return managed_names()
    end,
    desc = 'Update a linter',
  })

  api.nvim_create_user_command('LinterRemove', function(opts)
    M.remove(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return managed_names()
    end,
    desc = 'Remove a linter',
  })

  api.nvim_create_user_command('LinterUpdateCheck', function(opts)
    if opts.args ~= '' then
      M.check_one(opts.args)

      return
    end

    M.check(true)
  end, {
    nargs = '?',
    complete = function()
      return managed_names()
    end,
    desc = 'Check linter versions',
  })

  vim.defer_fn(function()
    M.check(false)
  end, 2000)
end

return M
