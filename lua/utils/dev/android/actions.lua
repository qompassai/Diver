-- #################################################################
-- /qompassai/lua/utils/dev/android/actions.lua
-- Qompass AI Actions
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
-- /qompassai/utils/dev/android/actions.lua
-- Qompass AI Android Actions
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################

local M = {}

local notify = vim.notify
local levels = vim.log.levels

local devices = require('utils.dev.android.devices')
local gradle = require('utils.dev.android.gradle')
local output = require('utils.dev.android.output')
local recent = require('utils.dev.android.recent')
local ui = require('utils.dev.android.ui')
local util = require('utils.dev.android.util')

local function run_cli_with_progress(title, message, args, opts)
  opts = opts or {}

  local progress = output.create_task_progress(title)
  local timer = output.start_progress_timer(progress, message)
  local buf = opts.show_output and output.create_build_window() or nil
  local system_opts = buf and output.create_gradle_system_opts(buf) or { text = true }

  if opts.env then
    system_opts.env = opts.env
  end

  vim.system(
    util.android_cli_cmd(args),
    system_opts,
    vim.schedule_wrap(function(obj)
      timer:stop()

      if obj.code == 0 then
        progress.done(true, opts.success or 'Done.')
        if opts.on_success then
          opts.on_success(obj)
        end
      else
        progress.done(false, opts.failure or 'Failed.')
        notify(util.trim(obj.stderr or obj.stdout or 'Command failed.'), levels.ERROR, {})
      end
    end)
  )
end

function M.refresh_dependencies()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('Refresh failed: gradlew is not found.', levels.ERROR, {})
    return
  end

  local progress = output.create_task_progress('AndroidRefreshDependencies')
  local timer = output.start_progress_timer(progress, 'Refreshing dependencies')
  local buf = output.create_build_window()

  vim.system(
    { gradlew.gradlew, '--refresh-dependencies' },
    output.create_gradle_system_opts(buf),
    vim.schedule_wrap(function(obj)
      timer:stop()

      if obj.code == 0 then
        progress.done(true, 'Dependencies refreshed.')
        notify('Dependencies refreshed.', levels.INFO, {})
      else
        progress.done(false, 'Refresh failed.')
        notify('Refresh failed: ' .. (obj.stderr or ''), levels.ERROR, {})
      end
    end)
  )
end

function M.build_release()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('Build failed: gradlew is not found.', levels.ERROR, {})
    return
  end

  local progress = output.create_task_progress('AndroidBuildRelease')
  local timer = output.start_progress_timer(progress, 'Building release')
  local buf = output.create_build_window()

  vim.system(
    { gradlew.gradlew, 'assembleRelease' },
    output.create_gradle_system_opts(buf),
    vim.schedule_wrap(function(obj)
      timer:stop()

      if obj.code == 0 then
        progress.done(true, 'Build successful.')
        notify('Build successful.', levels.INFO, {})
      else
        progress.done(false, 'Build failed.')
        notify('Build failed: ' .. (obj.stderr or ''), levels.ERROR, {})
      end
    end)
  )
end

function M.clean()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('Clean failed: gradlew is not found.', levels.ERROR, {})
    return
  end

  local progress = output.create_task_progress('AndroidClean')
  local timer = output.start_progress_timer(progress, 'Cleaning')
  local buf = output.create_build_window()

  vim.system(
    { gradlew.gradlew, 'clean' },
    output.create_gradle_system_opts(buf),
    vim.schedule_wrap(function(obj)
      timer:stop()

      if obj.code == 0 then
        progress.done(true, 'Clean successful.')
        notify('Clean successful.', levels.INFO, {})
      else
        progress.done(false, 'Clean failed.')
        notify('Clean failed: ' .. (obj.stderr or ''), levels.ERROR, {})
      end
    end)
  )
end

function M.build_and_install(root_dir, gradle_bin, adb, device, module)
  module = module or 'app'

  local application_id = gradle.find_application_id(root_dir, module)
  if application_id == nil then
    notify('Build failed: could not find applicationId for module ' .. module, levels.ERROR, {})
    return
  end

  local progress = output.create_task_progress('AndroidRun')
  local timer = output.start_progress_timer(progress, 'Building ' .. module)
  local buf = output.create_build_window()

  vim.system(
    { gradle_bin, gradle.gradle_module_name(module) .. ':assembleDebug' },
    output.create_gradle_system_opts(buf),
    vim.schedule_wrap(function(obj)
      timer:stop()

      if obj.code ~= 0 then
        progress.done(false, 'Build failed.')
        notify('Build failed.', levels.ERROR, {})
        return
      end

      local apk_path = gradle.find_debug_apk(root_dir, module)
      if apk_path == nil then
        progress.done(false, 'Installation failed: debug APK not found.')
        notify('Installation failed: could not find debug APK for module ' .. module, levels.ERROR, {})
        return
      end

      local apk_name = vim.fn.fnamemodify(apk_path, ':t')
      progress.tick(75, 'Installing ' .. apk_name .. '...')

      local install_obj = vim.system({ adb, '-s', device.id, 'install', '-r', apk_path }, {}):wait()
      if install_obj.code ~= 0 then
        progress.done(false, 'Installation failed.')
        notify('Installation failed: ' .. (install_obj.stderr or ''), levels.ERROR, {})
        return
      end

      progress.tick(90, 'Launching ' .. application_id .. '...')

      local main_activity = devices.find_main_activity(adb, device.id, application_id)
      if main_activity == nil then
        progress.done(false, 'Launch failed: main activity not found.')
        notify('Failed to launch application, did not find main activity', levels.ERROR, {})
        return
      end

      local launch_obj = vim
        .system({
          adb,
          '-s',
          device.id,
          'shell',
          'am',
          'start',
          '-a',
          'android.intent.action.MAIN',
          '-c',
          'android.intent.category.LAUNCHER',
          '-n',
          main_activity,
        }, {})
        :wait()

      if launch_obj.code ~= 0 then
        progress.done(false, 'Launch failed.')
        notify('Failed to launch application: ' .. (launch_obj.stderr or ''), levels.ERROR, {})
        return
      end

      local success_message = 'Launched ' .. application_id .. ' from ' .. apk_name
      progress.done(true, success_message .. '.')
      notify('Successfully built and launched ' .. application_id .. ' from ' .. apk_name .. '!', levels.INFO, {})

      output.close_build_window()
    end)
  )
end

function M.build_and_run()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('Build failed: gradlew is not found.', levels.ERROR, {})
    return
  end

  local sdk = util.get_android_sdk()
  if sdk == nil or #sdk == 0 then
    notify('Android SDK is not defined.', levels.ERROR, {})
    return
  end

  local adb = sdk .. '/platform-tools/adb'
  local running_devices = devices.get_running_devices(adb)
  if #running_devices == 0 then
    notify('Build failed: no devices are running.', levels.WARN, {})
    return
  end

  local application_modules = gradle.find_application_modules(gradlew.cwd)
  if #application_modules == 0 then
    notify('Build failed: no application module found.', levels.ERROR, {})
    return
  end

  local function run_on_device(device, module)
    notify('Device selected: ' .. device.name .. ' | module: ' .. module, levels.INFO, {})
    M.build_and_install(gradlew.cwd, gradlew.gradlew, adb, device, module)
  end

  local function select_device(module)
    ui.select_modal(running_devices, {
      prompt = 'Select device to run on',
      format_item = function(item)
        return item.name
      end,
    }, function(choice)
      if choice then
        run_on_device(choice, module)
      else
        notify('Build cancelled.', levels.WARN, {})
      end
    end)
  end

  if #application_modules == 1 then
    select_device(application_modules[1])
    return
  end

  ui.select_modal(application_modules, {
    prompt = 'Select application module',
    format_item = function(item)
      local app_id = gradle.find_application_id(gradlew.cwd, item)
      if app_id then
        return item .. ' (' .. app_id .. ')'
      end
      return item
    end,
  }, function(module)
    if module then
      select_device(module)
    else
      notify('Build cancelled.', levels.WARN, {})
    end
  end)
end

function M.uninstall()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('Uninstall failed: gradlew is not found.', levels.ERROR, {})
    return
  end

  local application_modules = gradle.find_application_modules(gradlew.cwd)
  local application_id = application_modules[1] and gradle.find_application_id(gradlew.cwd, application_modules[1])

  if application_id == nil then
    notify('Uninstall failed: could not find application id.', levels.ERROR, {})
    return
  end

  local sdk = util.get_android_sdk()
  if sdk == nil or #sdk == 0 then
    notify('Android SDK is not defined.', levels.ERROR, {})
    return
  end

  local adb = sdk .. '/platform-tools/adb'
  local running_devices = devices.get_running_devices(adb)
  if #running_devices == 0 then
    notify('Uninstall failed: no devices are running.', levels.WARN, {})
    return
  end

  ui.select_modal(running_devices, {
    prompt = 'Select device to uninstall from',
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if choice then
      local progress = output.create_task_progress('AndroidUninstall')
      local timer = output.start_progress_timer(progress, 'Uninstalling ' .. application_id)
      local uninstall_obj = vim.system({ adb, '-s', choice.id, 'uninstall', application_id }, {}):wait()

      timer:stop()

      if uninstall_obj.code == 0 then
        progress.done(true, 'Uninstall successful.')
        notify('Uninstall successful.', levels.INFO, {})
      else
        progress.done(false, 'Uninstall failed.')
        notify('Uninstall failed: ' .. (uninstall_obj.stderr or ''), levels.ERROR, {})
      end
    else
      notify('Uninstall cancelled.', levels.WARN, {})
    end
  end)
end

function M.start_emulator_picker()
  local avds, err = devices.list_avds()
  if avds == nil then
    notify(err, levels.ERROR, {})
    return
  end

  if #avds == 0 then
    notify('No emulators found.', levels.WARN, {})
    return
  end

  ui.select_modal(avds, {
    prompt = 'AVD to start',
  }, function(choice)
    if choice then
      run_cli_with_progress('LaunchAvd', 'Launching ' .. choice, {
        'emulator',
        'start',
        choice,
      }, {
        success = 'Launched ' .. choice .. '.',
      })
    end
  end)
end

function M.stop_avd()
  devices.with_adb(function(adb)
    local emulators = {}

    for _, device in ipairs(devices.get_running_devices(adb)) do
      if device.id:match('^emulator') then
        emulators[#emulators + 1] = device
      end
    end

    if #emulators == 0 then
      notify('No running emulators found.', levels.WARN, {})
      return
    end

    local function stop_device(device)
      run_cli_with_progress('StopAvd', 'Stopping ' .. device.name, {
        'emulator',
        'stop',
        device.id,
      }, {
        success = 'Stopped ' .. device.name .. '.',
      })
    end

    if #emulators == 1 then
      stop_device(emulators[1])
      return
    end

    ui.select_modal(emulators, {
      prompt = 'Emulator to stop',
      format_item = function(device)
        return device.name .. ' (' .. device.id .. ')'
      end,
    }, function(choice)
      if choice then
        stop_device(choice)
      end
    end)
  end)
end

function M.open_in_android_studio()
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' or vim.bo[0].buftype ~= '' then
    notify('Open a file buffer first.', levels.WARN, {})
    return
  end

  file = vim.fn.fnamemodify(file, ':p')

  local gradlew = util.find_gradlew()
  local args = { 'studio', 'open-file', file }

  if gradlew then
    args[#args + 1] = '--project=' .. gradlew.cwd
  end

  run_cli_with_progress('AndroidStudio', 'Opening in Android Studio', args, {
    success = 'Opened in Android Studio.',
  })
end

function M.studio_check()
  run_cli_with_progress('AndroidStudio', 'Checking Android Studio', {
    'studio',
    'check',
  }, {
    show_output = true,
    success = 'Studio check complete.',
  })
end

function M.capture_screen()
  devices.with_adb(function(adb)
    local running_devices = devices.get_running_devices(adb)
    if #running_devices == 0 then
      notify('No devices are running.', levels.WARN, {})
      return
    end

    ui.select_modal(running_devices, {
      prompt = 'Select device for screenshot',
      format_item = function(device)
        return device.name .. ' (' .. device.id .. ')'
      end,
    }, function(choice)
      if not choice then
        return
      end

      local screenshot = vim.fn.tempname() .. '.png'
      run_cli_with_progress('AndroidScreen', 'Capturing screen', {
        'screen',
        'capture',
        '-o=' .. screenshot,
      }, {
        env = {
          ANDROID_SERIAL = choice.id,
        },
        success = 'Screenshot saved.',
        on_success = function()
          notify('Screenshot: ' .. screenshot, levels.INFO, {})
        end,
      })
    end)
  end)
end

function M.dump_layout()
  devices.with_adb(function(adb)
    local running_devices = devices.get_running_devices(adb)
    if #running_devices == 0 then
      notify('No devices are running.', levels.WARN, {})
      return
    end

    ui.select_modal(running_devices, {
      prompt = 'Select device for layout dump',
      format_item = function(device)
        return device.name .. ' (' .. device.id .. ')'
      end,
    }, function(choice)
      if not choice then
        return
      end

      run_cli_with_progress('AndroidLayout', 'Dumping layout', {
        'layout',
        '--device=' .. choice.id,
        '-p',
      }, {
        show_output = true,
        success = 'Layout dump complete.',
      })
    end)
  end)
end

function M.describe_project()
  local gradlew = util.find_gradlew()
  if gradlew == nil then
    notify('gradlew is not found.', levels.ERROR, {})
    return
  end

  run_cli_with_progress('AndroidDescribe', 'Describing project', {
    'describe',
    '--project_dir=' .. gradlew.cwd,
  }, {
    show_output = true,
    success = 'Project describe complete.',
  })
end
function M.show_android_info()
  run_cli_with_progress('AndroidInfo', 'Fetching Android info', {
    'info',
  }, {
    show_output = true,
    success = 'Environment info loaded.',
  })
end
function M.android_run_cli()
  devices.with_adb(function(adb)
    local running_devices = devices.get_running_devices(adb)
    if #running_devices == 0 then
      notify('No devices are running.', levels.WARN, {})
      return
    end

    ui.select_modal(running_devices, {
      prompt = 'Select device to run on',
      format_item = function(device)
        return device.name .. ' (' .. device.id .. ')'
      end,
    }, function(choice)
      if not choice then
        return
      end

      run_cli_with_progress('AndroidRun', 'Running app', {
        'run',
        '--debug',
        '--device=' .. choice.id,
      }, {
        show_output = true,
        success = 'App deployed.',
      })
    end)
  end)
end
function M.get_actions()
  return {
    {
      id = 'run_debug',
      label = 'Run debug app',
      group = 'Build & deploy',
      keywords = 'run debug gradle install launch adb',
      run = M.build_and_run,
    },
    {
      id = 'run_cli',
      label = 'Run with android CLI',
      group = 'Build & deploy',
      keywords = 'run deploy android cli debug',
      run = M.android_run_cli,
    },
    {
      id = 'build_release',
      label = 'Build release',
      group = 'Build & deploy',
      keywords = 'build release gradle assemble',
      run = M.build_release,
    },
    {
      id = 'clean',
      label = 'Clean project',
      group = 'Build & deploy',
      keywords = 'clean gradle build',
      run = M.clean,
    },
    {
      id = 'refresh_dependencies',
      label = 'Refresh dependencies',
      group = 'Build & deploy',
      keywords = 'refresh dependencies gradle cache',
      run = M.refresh_dependencies,
    },
    {
      id = 'uninstall',
      label = 'Uninstall app',
      group = 'Build & deploy',
      keywords = 'uninstall remove adb app',
      run = M.uninstall,
    },
    {
      id = 'start_emulator',
      label = 'Start emulator',
      group = 'Emulator',
      keywords = 'emulator avd start launch',
      run = M.start_emulator_picker,
    },
    {
      id = 'stop_emulator',
      label = 'Stop emulator',
      group = 'Emulator',
      keywords = 'emulator avd stop',
      run = M.stop_avd,
    },
    {
      id = 'open_studio_file',
      label = 'Open current file in Android Studio',
      group = 'Android Studio',
      keywords = 'studio open file ide',
      run = M.open_in_android_studio,
    },
    {
      id = 'studio_check',
      label = 'Check Studio status',
      group = 'Android Studio',
      keywords = 'studio check status ide',
      run = M.studio_check,
    },
    {
      id = 'capture_screen',
      label = 'Capture screen',
      group = 'Device',
      keywords = 'screen screenshot capture device',
      run = M.capture_screen,
    },
    {
      id = 'dump_layout',
      label = 'Dump layout tree',
      group = 'Device',
      keywords = 'layout ui dump hierarchy device',
      run = M.dump_layout,
    },
    {
      id = 'describe_project',
      label = 'Describe project',
      group = 'Project',
      keywords = 'describe project metadata gradle',
      run = M.describe_project,
    },
    {
      id = 'show_info',
      label = 'Show environment info',
      group = 'Project',
      keywords = 'info sdk environment android',
      run = M.show_android_info,
    },
  }
end

function M.build_action_map(actions)
  local out = {}

  for i = 1, #actions do
    local action = actions[i]
    out[action.id] = action
  end

  return out
end

function M.snake_to_pascal(str)
  return (str:gsub('(^%l)', string.upper):gsub('_(%l)', function(c)
    return c:upper()
  end))
end

function M.get_action_ids(actions, arg_lead)
  local ids = {}

  for i = 1, #actions do
    local id = actions[i].id
    if arg_lead == '' or vim.startswith(id, arg_lead) then
      ids[#ids + 1] = id
    end
  end

  return ids
end

function M.run_action(action)
  recent.record_recent_action(action.id)
  action.run()
end

function M.run_action_by_id(id)
  local actions = M.get_actions()
  local action_map = M.build_action_map(actions)
  local action = action_map[id]

  if not action then
    notify('Unknown Android action: ' .. id, levels.ERROR)
    return
  end

  M.run_action(action)
end

function M.show_menu()
  ui.select_root_menu(M.get_actions(), M.run_action)
end

return M
