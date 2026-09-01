-- #################################################################
-- /qompassai/Diver/lua/dap/android.lua
-- Native Android Debug Adapter Configuration
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026
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
---@source https://developer.android.com/studio/debug
---@source https://developer.android.com/studio/projects/add-native-code
---@source https://lldb.llvm.org/use/lldbdap.html
---@source https://lldb.llvm.org/use/remote.html

local api = vim.api
local env = vim.env
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local ADAPTER_NAME = 'android-lldb'

local DEFAULT_GDB_PORT = 5039
local DEFAULT_JDWP_PORT = 8700

local NOTIFY_PREFIX = '[android-debug] '

---@class AndroidDebugState
---@field android_root? string
---@field application_id? string
---@field device? string
---@field lldb_server_job? vim.SystemObj
---@field native_library? string
---@field pid? integer
---@field remote_port? integer

---@type AndroidDebugState
local state = {}

---@type string[]
local PROJECT_ROOT_MARKERS = {
  'Cargo.toml',
  'build.gradle.kts',
  'build.gradle',
  'settings.gradle.kts',
  'settings.gradle',
  '.git',
}

---@type table<string, string[]>
local ABI_PATTERNS = {
  ['arm64-v8a'] = {
    'arm64-v8a',
    'aarch64',
  },

  ['armeabi-v7a'] = {
    'armeabi-v7a',
    'arm',
  },

  ['x86'] = {
    '/x86/',
    'i686',
  },

  ['x86_64'] = {
    'x86_64',
  },
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param command string
---@return boolean
local function is_executable(command)
  return fn.executable(command) == 1
end

---@param path string
---@return boolean
local function exists(path)
  return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_directory(path)
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

---@param path string
---@return string?
local function read_file(path)
  local file = io.open(path, 'rb')

  if file == nil then
    return nil
  end

  local content = file:read('*a')

  file:close()

  if type(content) ~= 'string' or content == '' then
    return nil
  end

  return content
end

---@param command string[]
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted
local function system(command, opts)
  assert(type(command) == 'table' and #command > 0, 'command must be a non-empty argv table')

  opts = vim.tbl_extend('force', {
    text = true,
  }, opts or {})

  return vim.system(command, opts):wait()
end

---@param result vim.SystemCompleted
---@param context string
---@return boolean
local function check_result(result, context)
  if result.code == 0 then
    return true
  end

  local detail = result.stderr

  if type(detail) ~= 'string' or detail == '' then
    detail = result.stdout
  end

  detail = type(detail) == 'string' and vim.trim(detail) or ''

  if detail == '' then
    detail = ('exit status %d'):format(result.code)
  end

  notify(('%s failed: %s'):format(context, detail), levels.ERROR)

  return false
end

---@param bufnr? integer
---@return string
local function current_filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  return normalize(api.nvim_buf_get_name(bufnr))
end

---@param start string
---@return string?
local function project_root(start)
  if start == '' then
    return nil
  end

  return fs.root(start, PROJECT_ROOT_MARKERS)
end

---@param start? string
---@return string?
local function find_android_root(start)
  if state.android_root ~= nil and is_directory(state.android_root) then
    return state.android_root
  end

  start = start or current_filename()

  if start == '' then
    start = fn.getcwd()
  end

  local current = is_directory(start) and normalize(start) or normalize(fs.dirname(start) or fn.getcwd())

  while current ~= '' do
    local has_app = exists(fs.joinpath(current, 'app', 'build.gradle.kts'))
      or exists(fs.joinpath(current, 'app', 'build.gradle'))

    local has_settings = exists(fs.joinpath(current, 'settings.gradle.kts'))
      or exists(fs.joinpath(current, 'settings.gradle'))

    if has_app and has_settings then
      state.android_root = current

      return current
    end

    local ontrack_android = fs.joinpath(current, 'crates', 'ontrack-mobile', 'android')

    if exists(fs.joinpath(ontrack_android, 'app', 'build.gradle.kts')) then
      state.android_root = normalize(ontrack_android)

      return state.android_root
    end

    local parent = fs.dirname(current)

    if parent == nil or parent == current then
      break
    end

    current = parent
  end

  return nil
end

---@param root string
---@return string?
local function app_build_file(root)
  local candidates = {
    fs.joinpath(root, 'app', 'build.gradle.kts'),

    fs.joinpath(root, 'app', 'build.gradle'),
  }

  for index = 1, #candidates do
    if exists(candidates[index]) then
      return candidates[index]
    end
  end

  return nil
end

---@param root string
---@return string?
local function manifest_file(root)
  local path = fs.joinpath(root, 'app', 'src', 'main', 'AndroidManifest.xml')

  if exists(path) then
    return path
  end

  return nil
end

---@param root string
---@return string?
local function application_id(root)
  local configured = env.ANDROID_APP_ID

  if type(configured) == 'string' and configured ~= '' then
    return configured
  end

  if state.application_id ~= nil then
    return state.application_id
  end

  local build_file = app_build_file(root)

  if build_file == nil then
    return nil
  end

  local content = read_file(build_file)

  if content == nil then
    return nil
  end

  local value = content:match('applicationId%s*=%s*"([^"]+)"')

  if value == nil then
    value = content:match("applicationId%s*=%s*'([^']+)'")
  end

  if type(value) == 'string' and value ~= '' then
    state.application_id = value

    return value
  end

  return nil
end

---@param root string
---@return string
local function activity_name(root)
  local configured = env.ANDROID_ACTIVITY

  if type(configured) == 'string' and configured ~= '' then
    return configured
  end

  local manifest = manifest_file(root)

  if manifest == nil then
    return 'android.app.NativeActivity'
  end

  local content = read_file(manifest)

  if content == nil then
    return 'android.app.NativeActivity'
  end

  if content:find('android.app.NativeActivity', 1, true) ~= nil then
    return 'android.app.NativeActivity'
  end

  local activity = content:match('<activity.-android:name%s*=%s*"([^"]+)"')

  if type(activity) == 'string' and activity ~= '' then
    return activity
  end

  return 'android.app.NativeActivity'
end

---@param root string
---@return string?
local function native_library_name(root)
  local configured = env.ANDROID_NATIVE_LIBRARY

  if type(configured) == 'string' and configured ~= '' then
    return configured
  end

  local manifest = manifest_file(root)

  if manifest == nil then
    return nil
  end

  local content = read_file(manifest)

  if content == nil then
    return nil
  end

  return content:match('android:name%s*=%s*"android%.app%.lib_name".-android:value%s*=%s*"([^"]+)"')
end

---@return string?
local function adb()
  local configured = env.ADB

  if type(configured) == 'string' and configured ~= '' and is_executable(configured) then
    return configured
  end

  if is_executable('adb') then
    return 'adb'
  end

  local sdk = env.ANDROID_SDK_ROOT or env.ANDROID_HOME

  if type(sdk) == 'string' and sdk ~= '' then
    local candidate = fs.joinpath(sdk, 'platform-tools', 'adb')

    if exists(candidate) then
      return candidate
    end
  end

  return nil
end

---@return string?
local function lldb_dap()
  local configured = env.LLDB_DAP

  if type(configured) == 'string' and configured ~= '' and is_executable(configured) then
    return configured
  end

  local candidates = {
    'lldb-dap',
    'lldb-vscode',
  }

  for index = 1, #candidates do
    if is_executable(candidates[index]) then
      return candidates[index]
    end
  end

  return nil
end

---@return string?
local function gradle()
  local configured = env.GRADLE

  if type(configured) == 'string' and configured ~= '' and is_executable(configured) then
    return configured
  end

  if is_executable('gradle') then
    return 'gradle'
  end

  return nil
end

---@param root string
---@return string?
local function gradle_command(root)
  local candidates = {
    fs.joinpath(root, 'gradlew'),

    fs.joinpath(fs.dirname(root) or root, 'gradlew'),
  }

  local workspace = project_root(root)

  if workspace ~= nil then
    candidates[#candidates + 1] = fs.joinpath(workspace, 'gradlew')
  end

  for index = 1, #candidates do
    if exists(candidates[index]) then
      return candidates[index]
    end
  end

  return gradle()
end

---@param serial string?
---@param arguments string[]
---@return string[]?
local function adb_command(serial, arguments)
  local command = adb()

  if command == nil then
    notify('adb is not available', levels.ERROR)

    return nil
  end

  local argv = {
    command,
  }

  if type(serial) == 'string' and serial ~= '' then
    argv[#argv + 1] = '-s'

    argv[#argv + 1] = serial
  end

  for index = 1, #arguments do
    argv[#argv + 1] = arguments[index]
  end

  return argv
end

---@return table[]
local function devices()
  local argv = adb_command(nil, {
    'devices',
    '-l',
  })

  if argv == nil then
    return {}
  end

  local result = system(argv)

  if result.code ~= 0 then
    return {}
  end

  ---@type table[]
  local result_devices = {}

  for line in (result.stdout or ''):gmatch('[^\r\n]+') do
    local serial, status = line:match('^(%S+)%s+(%S+)')

    if serial ~= nil and status == 'device' and serial ~= 'List' then
      local model = line:match('model:(%S+)')

      result_devices[#result_devices + 1] = {
        label = model ~= nil and (model .. ' [' .. serial .. ']') or serial,

        serial = serial,
      }
    end
  end

  return result_devices
end

---@return string?
local function current_device()
  local configured = env.ANDROID_SERIAL

  if type(configured) == 'string' and configured ~= '' then
    return configured
  end

  if state.device ~= nil and state.device ~= '' then
    return state.device
  end

  local available = devices()

  if #available == 1 then
    state.device = available[1].serial

    return state.device
  end

  if #available == 0 then
    notify('no authorized Android device or emulator is connected', levels.ERROR)
  else
    notify('multiple Android devices are connected; run :AndroidSelectDevice', levels.WARN)
  end

  return nil
end

local function select_device()
  local available = devices()

  if #available == 0 then
    notify('no authorized Android devices found', levels.ERROR)

    return
  end

  vim.ui.select(available, {
    prompt = 'Android device: ',

    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice == nil then
      return
    end

    state.device = choice.serial

    notify('selected ' .. choice.label)
  end)
end

---@param serial string
---@return string?
local function device_abi(serial)
  local argv = adb_command(serial, {
    'shell',
    'getprop',
    'ro.product.cpu.abi',
  })

  if argv == nil then
    return nil
  end

  local result = system(argv)

  if result.code ~= 0 then
    return nil
  end

  local abi = vim.trim(result.stdout or '')

  if abi == '' then
    return nil
  end

  return abi
end

---@param root string
---@return boolean
local function build_debug(root)
  local command = gradle_command(root)

  if command == nil then
    notify('Gradle is not available', levels.ERROR)

    return false
  end

  local task = env.ANDROID_GRADLE_TASK

  if type(task) ~= 'string' or task == '' then
    task = ':app:assembleDebug'
  end

  local result = system({
    command,
    '-p',
    root,
    task,
  }, {
    cwd = root,
  })

  return check_result(result, 'Android debug build')
end

---@param root string
---@return string?
local function debug_apk(root)
  local configured = env.ANDROID_APK

  if type(configured) == 'string' and configured ~= '' and exists(configured) then
    return normalize(configured)
  end

  local output = fs.joinpath(root, 'app', 'build', 'outputs', 'apk', 'debug')

  if not is_directory(output) then
    return nil
  end

  local matches = fn.glob(fs.joinpath(output, '*.apk'), false, true)

  table.sort(matches)

  for index = 1, #matches do
    if matches[index]:find('debug', 1, true) ~= nil then
      return normalize(matches[index])
    end
  end

  if #matches > 0 then
    return normalize(matches[1])
  end

  return nil
end

---@param serial string
---@param apk string
---@return boolean
local function install_apk(serial, apk)
  local argv = adb_command(serial, {
    'install',
    '-r',
    '-t',
    apk,
  })

  if argv == nil then
    return false
  end

  return check_result(system(argv), 'APK install')
end

---@param serial string
---@param package string
local function force_stop(serial, package)
  local argv = adb_command(serial, {
    'shell',
    'am',
    'force-stop',
    package,
  })

  if argv ~= nil then
    system(argv)
  end
end

---@param serial string
---@param package string
---@param activity string
---@param wait_for_jdwp? boolean
---@return boolean
local function launch_app(serial, package, activity, wait_for_jdwp)
  force_stop(serial, package)

  local arguments = {
    'shell',
    'am',
    'start',
  }

  if wait_for_jdwp == true then
    arguments[#arguments + 1] = '-D'
  end

  arguments[#arguments + 1] = '-n'

  arguments[#arguments + 1] = package .. '/' .. activity

  local argv = adb_command(serial, arguments)

  if argv == nil then
    return false
  end

  return check_result(system(argv), 'Android app launch')
end

---@param serial string
---@param package string
---@return integer?
local function app_pid(serial, package)
  for _ = 1, 30 do
    local argv = adb_command(serial, {
      'shell',
      'pidof',
      package,
    })

    if argv ~= nil then
      local result = system(argv)

      if result.code == 0 then
        local value = (result.stdout or ''):match('(%d+)')

        local pid = tonumber(value)

        if pid ~= nil and pid > 0 then
          return math.floor(pid)
        end
      end
    end

    vim.wait(100)
  end

  return nil
end

---@param serial string
---@param package string
---@return boolean
local function check_run_as(serial, package)
  local argv = adb_command(serial, {
    'shell',
    'run-as',
    package,
    'pwd',
  })

  if argv == nil then
    return false
  end

  local result = system(argv)

  if result.code ~= 0 then
    notify('run-as failed; make sure the installed APK is a debuggable build', levels.ERROR)

    return false
  end

  return true
end

---@return string[]
local function sdk_roots()
  local roots = {}

  local candidates = {
    env.ANDROID_NDK_HOME,
    env.ANDROID_NDK_ROOT,
  }

  for index = 1, #candidates do
    local candidate = candidates[index]

    if type(candidate) == 'string' and candidate ~= '' and is_directory(candidate) then
      roots[#roots + 1] = normalize(candidate)
    end
  end

  local sdk = env.ANDROID_SDK_ROOT or env.ANDROID_HOME

  if type(sdk) == 'string' and sdk ~= '' then
    local ndk_dir = fs.joinpath(sdk, 'ndk')

    if is_directory(ndk_dir) then
      local versions = {}

      for name, kind in fs.dir(ndk_dir) do
        if kind == 'directory' then
          versions[#versions + 1] = fs.joinpath(ndk_dir, name)
        end
      end

      table.sort(versions, function(a, b)
        return a > b
      end)

      for index = 1, #versions do
        roots[#roots + 1] = normalize(versions[index])
      end
    end
  end

  return roots
end

---@param path string
---@param abi string
---@return boolean
local function matches_abi(path, abi)
  local patterns = ABI_PATTERNS[abi]

  if patterns == nil then
    return true
  end

  local lower = path:lower()

  for index = 1, #patterns do
    if lower:find(patterns[index]:lower(), 1, true) ~= nil then
      return true
    end
  end

  return false
end

---@param abi string
---@return string?
local function lldb_server(abi)
  local configured = env.ANDROID_LLDB_SERVER

  if type(configured) == 'string' and configured ~= '' and exists(configured) then
    return normalize(configured)
  end

  local sdk = env.ANDROID_SDK_ROOT or env.ANDROID_HOME

  if type(sdk) == 'string' and sdk ~= '' then
    local sdk_matches = fn.glob(fs.joinpath(sdk, 'lldb', '*', 'android', '*', 'lldb-server'), false, true)

    table.sort(sdk_matches, function(a, b)
      return a > b
    end)

    for index = 1, #sdk_matches do
      if matches_abi(sdk_matches[index], abi) then
        return normalize(sdk_matches[index])
      end
    end
  end

  local roots = sdk_roots()

  for root_index = 1, #roots do
    local matches = fn.glob(fs.joinpath(roots[root_index], '**', 'lldb-server'), false, true)

    for match_index = 1, #matches do
      if matches_abi(matches[match_index], abi) then
        return normalize(matches[match_index])
      end
    end
  end

  return nil
end

---@param root string
---@param abi string
---@return string?
local function native_library(root, abi)
  if state.native_library ~= nil and exists(state.native_library) then
    return state.native_library
  end

  local configured = env.ANDROID_NATIVE_LIBRARY_PATH

  if type(configured) == 'string' and configured ~= '' and exists(configured) then
    state.native_library = normalize(configured)

    return state.native_library
  end

  local name = native_library_name(root)

  if name == nil then
    return nil
  end

  local filename = 'lib' .. name .. '.so'

  local candidates = {
    fs.joinpath(root, 'app', 'src', 'main', 'jniLibs', abi, filename),

    fs.joinpath(root, 'app', 'build', 'intermediates'),
  }

  if exists(candidates[1]) then
    state.native_library = normalize(candidates[1])

    return state.native_library
  end

  if is_directory(candidates[2]) then
    local matches = fn.glob(fs.joinpath(candidates[2], '**', abi, filename), false, true)

    if #matches > 0 then
      state.native_library = normalize(matches[1])

      return state.native_library
    end
  end

  local workspace = project_root(root)

  if workspace ~= nil then
    local matches = fn.glob(fs.joinpath(workspace, '**', abi, filename), false, true)

    if #matches > 0 then
      state.native_library = normalize(matches[1])

      return state.native_library
    end
  end

  return nil
end

---@param serial string
---@param package string
---@param local_server string
---@return boolean
local function deploy_lldb_server(serial, package, local_server)
  local remote_tmp = '/data/local/tmp/nvim-lldb-server'

  local push = adb_command(serial, {
    'push',
    local_server,
    remote_tmp,
  })

  if push == nil or not check_result(system(push), 'lldb-server push') then
    return false
  end

  local copy = adb_command(serial, {
    'shell',
    'run-as',
    package,
    'cp',
    remote_tmp,
    './nvim-lldb-server',
  })

  if copy == nil or not check_result(system(copy), 'lldb-server install') then
    return false
  end

  local chmod = adb_command(serial, {
    'shell',
    'run-as',
    package,
    'chmod',
    '700',
    './nvim-lldb-server',
  })

  if chmod == nil then
    return false
  end

  return check_result(system(chmod), 'lldb-server chmod')
end

---@param serial string
---@param package string
local function stop_lldb_server(serial, package)
  if state.lldb_server_job ~= nil then
    pcall(state.lldb_server_job.kill, state.lldb_server_job, 15)

    state.lldb_server_job = nil
  end

  local argv = adb_command(serial, {
    'shell',
    'run-as',
    package,
    'pkill',
    '-f',
    'nvim-lldb-server',
  })

  if argv ~= nil then
    system(argv)
  end
end

---@param serial string
---@param package string
---@param port integer
---@return boolean
local function start_lldb_server(serial, package, port)
  stop_lldb_server(serial, package)

  local forward = adb_command(serial, {
    'forward',
    ('tcp:%d'):format(port),
    ('tcp:%d'):format(port),
  })

  if forward == nil or not check_result(system(forward), 'ADB LLDB port forwarding') then
    return false
  end

  local argv = adb_command(serial, {
    'shell',
    'run-as',
    package,
    './nvim-lldb-server',
    'platform',
    '--listen',
    ('*:%d'):format(port),
    '--server',
  })

  if argv == nil then
    return false
  end

  state.lldb_server_job = vim.system(argv, {
    text = true,
  }, function(result)
    if result.code ~= 0 and result.code ~= 143 then
      vim.schedule(function()
        notify('lldb-server exited unexpectedly', levels.WARN)
      end)
    end
  end)

  vim.wait(500)

  return true
end

---@param serial string
---@param port integer
local function remove_forward(serial, port)
  local argv = adb_command(serial, {
    'forward',
    '--remove',
    ('tcp:%d'):format(port),
  })

  if argv ~= nil then
    system(argv)
  end
end

---@return integer
local function native_port()
  local configured = tonumber(env.ANDROID_LLDB_PORT)

  if configured ~= nil and configured > 0 and configured <= 65535 then
    return math.floor(configured)
  end

  return DEFAULT_GDB_PORT
end

---@param build boolean
---@param install boolean
---@param launch boolean
---@return table?
local function prepare_native_session(build, install, launch)
  local root = find_android_root()

  if root == nil then
    notify('Android project root not found', levels.ERROR)

    return nil
  end

  local serial = current_device()

  if serial == nil then
    return nil
  end

  local package = application_id(root)

  if package == nil then
    notify('Android applicationId could not be determined', levels.ERROR)

    return nil
  end

  if build and not build_debug(root) then
    return nil
  end

  if install then
    local apk = debug_apk(root)

    if apk == nil then
      notify('debug APK not found', levels.ERROR)

      return nil
    end

    if not install_apk(serial, apk) then
      return nil
    end
  end

  if not check_run_as(serial, package) then
    return nil
  end

  if launch then
    if not launch_app(serial, package, activity_name(root), false) then
      return nil
    end
  end

  local pid = app_pid(serial, package)

  if pid == nil then
    notify('Android application process not found', levels.ERROR)

    return nil
  end

  local abi = device_abi(serial)

  if abi == nil then
    notify('Android device ABI could not be determined', levels.ERROR)

    return nil
  end

  local server = lldb_server(abi)

  if server == nil then
    notify('lldb-server was not found in the Android SDK/NDK', levels.ERROR)

    return nil
  end

  local library = native_library(root, abi)

  if library == nil then
    notify('local Android native library could not be found', levels.ERROR)

    return nil
  end

  if not deploy_lldb_server(serial, package, server) then
    return nil
  end

  local port = native_port()

  if not start_lldb_server(serial, package, port) then
    return nil
  end

  state.pid = pid

  state.remote_port = port

  return {
    abi = abi,
    library = library,
    package = package,
    pid = pid,
    port = port,
    root = root,
    serial = serial,
  }
end

---@return string?
local function prepare_build_install_launch()
  local session = prepare_native_session(true, true, true)

  if session == nil then
    return nil
  end

  return session.library
end

---@return string?
local function prepare_attach_running()
  local session = prepare_native_session(false, false, false)

  if session == nil then
    return nil
  end

  return session.library
end

---@return string[]
local function attach_commands()
  local package = state.application_id

  local pid = state.pid

  local port = state.remote_port

  if package == nil or pid == nil or port == nil then
    return {}
  end

  return {
    'platform select remote-android',

    ('settings set platform.plugin.remote-android.package-name %s'):format(package),

    ('platform connect connect://127.0.0.1:%d'):format(port),

    ('process attach -p %d'):format(pid),
  }
end

---@return string[]
local function rust_lldb_commands()
  local result = system({
    'rustc',
    '--print',
    'sysroot',
  })

  if result.code ~= 0 then
    return {}
  end

  local sysroot = normalize(vim.trim(result.stdout or ''))

  if sysroot == '' then
    return {}
  end

  local lookup = fs.joinpath(sysroot, 'lib', 'rustlib', 'etc', 'lldb_lookup.py')

  local commands = fs.joinpath(sysroot, 'lib', 'rustlib', 'etc', 'lldb_commands')
  ---@type string[]
  local init = {}
  if exists(lookup) then
    init[#init + 1] = ('command script import "%s"'):format(lookup:gsub('"', '\\"'))
  end

  local content = read_file(commands)

  if content ~= nil then
    for line in content:gmatch('[^\r\n]+') do
      if line ~= '' and not line:match('^%s*#') then
        init[#init + 1] = line
      end
    end
  end

  return init
end

local function build_install_launch()
  local root = find_android_root()

  if root == nil then
    notify('Android project root not found', levels.ERROR)

    return
  end

  local serial = current_device()

  if serial == nil then
    return
  end

  local package = application_id(root)

  if package == nil then
    notify('applicationId not found', levels.ERROR)

    return
  end

  if not build_debug(root) then
    return
  end

  local apk = debug_apk(root)

  if apk == nil then
    notify('debug APK not found', levels.ERROR)

    return
  end

  if not install_apk(serial, apk) then
    return
  end

  if launch_app(serial, package, activity_name(root), false) then
    notify('debug APK installed and launched')
  end
end

local function clear_app_data()
  local root = find_android_root()

  local serial = current_device()

  if root == nil or serial == nil then
    return
  end

  local package = application_id(root)

  if package == nil then
    return
  end

  local argv = adb_command(serial, {
    'shell',
    'pm',
    'clear',
    package,
  })

  if argv ~= nil and check_result(system(argv), 'clear application data') then
    notify('application data cleared')
  end
end

local function forward_jdwp()
  local root = find_android_root()

  local serial = current_device()

  if root == nil or serial == nil then
    return
  end

  local package = application_id(root)

  if package == nil then
    return
  end

  local pid = app_pid(serial, package)
  if pid == nil then
    notify('application process not found', levels.ERROR)

    return
  end
  local port = tonumber(env.ANDROID_JDWP_PORT) or DEFAULT_JDWP_PORT

  port = math.floor(port)

  local argv = adb_command(serial, {
    'forward',
    ('tcp:%d'):format(port),
    ('jdwp:%d'):format(pid),
  })

  if argv ~= nil and check_result(system(argv), 'JDWP forwarding') then
    notify(('JDWP forwarded to localhost:%d'):format(port))
  end
end

local function launch_waiting_for_jdwp()
  local root = find_android_root()

  local serial = current_device()

  if root == nil or serial == nil then
    return
  end

  local package = application_id(root)

  if package == nil then
    return
  end

  if launch_app(serial, package, activity_name(root), true) then
    notify('application launched waiting for JDWP')
  end
end

local function stop_debug_transport()
  local root = find_android_root()

  local serial = current_device()

  if root == nil or serial == nil then
    return
  end

  local package = application_id(root)

  if package == nil then
    return
  end

  stop_lldb_server(serial, package)

  remove_forward(serial, native_port())

  state.pid = nil

  state.remote_port = nil

  notify('Android debug transport stopped')
end

---@param name string
---@param callback function
---@param description string
local function create_command(name, callback, description)
  local commands = api.nvim_get_commands({
    builtin = false,
  })

  if commands[name] ~= nil then
    return
  end

  api.nvim_create_user_command(name, callback, {
    desc = description,
  })
end

M.adapter = {
  command = lldb_dap() or 'lldb-dap',

  name = ADAPTER_NAME,

  type = 'executable',
}

M.configurations = {
  rust = {
    {
      attachCommands = attach_commands,

      initCommands = rust_lldb_commands,

      name = 'Android: Build + install + launch + attach Rust',

      program = prepare_build_install_launch,

      request = 'attach',

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },

    {
      attachCommands = attach_commands,

      initCommands = rust_lldb_commands,

      name = 'Android: Attach running Rust app',

      program = prepare_attach_running,

      request = 'attach',

      stopOnEntry = false,

      type = ADAPTER_NAME,
    },
  },
}

M.filetypes = {
  'java',
  'kotlin',
  'rust',
}

---@param _opts? table
function M.setup(_opts)
  if adb() == nil then
    notify('adb is not available', levels.WARN)
  end

  local adapter = lldb_dap()

  if adapter == nil then
    notify('lldb-dap is not available', levels.WARN)
  else
    M.adapter.command = adapter
  end

  create_command(
    'AndroidBuildInstallLaunch',
    build_install_launch,
    'Build, install, and launch Android debug application'
  )

  create_command('AndroidClearAppData', clear_app_data, 'Clear Android application data')

  create_command('AndroidForwardJdwp', forward_jdwp, 'Forward running Android process JDWP port')
  create_command('AndroidLaunchJdwp', launch_waiting_for_jdwp, 'Launch Android application waiting for JDWP')
  create_command('AndroidSelectDevice', select_device, 'Select Android debug device or emulator')
  create_command('AndroidStopDebugTransport', stop_debug_transport, 'Stop Android LLDB transport and port forwarding')
end

return M
