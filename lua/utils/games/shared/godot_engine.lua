-- #################################################################
-- /qompassai/Diver/lua/utils/games/shared/godot_engine.lua
-- Qompass AI Godot-compatible Engine Factory
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
local shared_util = require('utils.games.shared.util')
local shared_ui = require('utils.games.shared.ui')
local output_factory = require('utils.games.shared.output')
local events = require('utils.games.shared.events')
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local json = vim.json
local levels = vim.log.levels
local notify = vim.notify
local uv = vim.uv or vim.uv

local M = {}
local DEFAULT_REMOTE_DEBUG_HOST = '127.0.0.1'
local DEFAULT_REMOTE_DEBUG_PORT = 6007
local EXPORT_SCAN_MAX_DEPTH = 16
local EXPORT_SCAN_MAX_ENTRIES = 20000
local EXPORT_SCAN_IGNORED_DIRS = {
  ['.git'] = true,
  ['.godot'] = true,
  ['.import'] = true,
  ['.mono'] = true,
}

local EXPORT_SCAN_RELEVANT_EXTENSIONS = {
  gd = true,
  import = true,
  tscn = true,
}

---@class GamesExportManifest
---@field files table<string, string>
---@field saved_at? integer

---@class GamesGodotEngineOptions
---@field name string
---@field command_prefix? string
---@field leader? string
---@field binaries? string[]
---@field env_names? string[]
---@field root_markers? string[]
---@field output_filetype? string

---@param message string
---@param level? integer
local function game_notify(message, level)
  assert(type(message) == 'string' and message ~= '')

  notify(message, level or levels.INFO)
end

---@param path string
---@return string
local function normalize(path)
  assert(type(path) == 'string')

  if path == '' then
    return ''
  end

  return fs.normalize(fn.fnamemodify(fn.expand(path), ':p'))
end

---@param path string
---@return boolean
local function is_directory(path)
  assert(type(path) == 'string')

  if path == '' then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil and stat.type == 'directory'
end

---@param value unknown
---@return string?
local function nonempty_string(value)
  if type(value) ~= 'string' then
    return nil
  end

  local trimmed = shared_util.trim(value)

  if trimmed == '' then
    return nil
  end

  return trimmed
end

---@param prompt string
---@param default string
---@param completion? string
---@return string?
local function prompt_nonempty(prompt, default, completion)
  assert(type(prompt) == 'string' and prompt ~= '')
  assert(type(default) == 'string')

  local value = fn.input(prompt, default, completion)

  return nonempty_string(value)
end

---@param prompt string
---@param default integer
---@param minimum integer
---@param maximum integer
---@return integer?
local function prompt_integer_in_range(prompt, default, minimum, maximum)
  assert(type(prompt) == 'string' and prompt ~= '')
  assert(type(default) == 'number')
  assert(type(minimum) == 'number')
  assert(type(maximum) == 'number')
  assert(minimum <= maximum)

  local input = prompt_nonempty(prompt, tostring(default))

  if input == nil then
    return nil
  end

  local number = tonumber(input)

  if number == nil then
    return nil
  end

  if number ~= math.floor(number) then
    return nil
  end

  if number < minimum or number > maximum then
    return nil
  end

  ---@cast number integer

  return number
end

---@param command string[]
---@param label string
---@return boolean
local function start_detached(command, label)
  assert(type(command) == 'table' and #command > 0)
  assert(type(label) == 'string' and label ~= '')

  local job_id = fn.jobstart(command, {
    detach = true,
  })

  if type(job_id) ~= 'number' or job_id <= 0 then
    game_notify(label .. ': failed to start process.', levels.ERROR)
    return false
  end

  return true
end

---@param root string
---@param out_files string[]
---@param entry_counter integer[]
---@param depth integer
local function scan_export_relevant_files(root, out_files, entry_counter, depth)
  assert(type(root) == 'string' and root ~= '')
  assert(type(out_files) == 'table')
  assert(type(entry_counter) == 'table' and type(entry_counter[1]) == 'number')
  assert(type(depth) == 'number' and depth >= 0)

  if depth > EXPORT_SCAN_MAX_DEPTH then
    return
  end

  if entry_counter[1] >= EXPORT_SCAN_MAX_ENTRIES then
    return
  end

  local handle = uv.fs_scandir(root)

  if handle == nil then
    return
  end

  while entry_counter[1] < EXPORT_SCAN_MAX_ENTRIES do
    local entry_name, entry_type = uv.fs_scandir_next(handle)

    if entry_name == nil then
      return
    end

    entry_counter[1] = entry_counter[1] + 1

    local full_path = root .. '/' .. entry_name

    if entry_type == 'directory' then
      if not EXPORT_SCAN_IGNORED_DIRS[entry_name] then
        scan_export_relevant_files(full_path, out_files, entry_counter, depth + 1)
      end
    elseif entry_type == 'file' then
      local extension = entry_name:match('%.([%w]+)$')

      if extension ~= nil and EXPORT_SCAN_RELEVANT_EXTENSIONS[extension] then
        out_files[#out_files + 1] = full_path
      end
    end
  end
end

---@param stat table
---@return string?
local function stat_mtime_key(stat)
  assert(type(stat) == 'table')

  local mtime = stat.mtime

  if type(mtime) ~= 'table' then
    return nil
  end

  if type(mtime.sec) ~= 'number' or type(mtime.nsec) ~= 'number' then
    return nil
  end

  return tostring(mtime.sec) .. ':' .. tostring(mtime.nsec)
end

---@param engine_name string
---@return string
local function export_manifest_path(engine_name)
  assert(type(engine_name) == 'string' and engine_name ~= '')

  local state_directory = normalize(fn.stdpath('state') .. '/games-nvim')

  assert(state_directory ~= '')

  fn.mkdir(state_directory, 'p')

  return state_directory .. '/' .. engine_name:lower() .. '-export-state.json'
end

---@param path string
---@return GamesExportManifest
local function read_export_manifest(path)
  assert(type(path) == 'string' and path ~= '')

  local ok, contents = pcall(shared_util.read_file, path)

  if not ok or type(contents) ~= 'string' or contents == '' then
    return {
      files = {},
    }
  end

  local decode_ok, decoded = pcall(json.decode, contents)

  if not decode_ok or type(decoded) ~= 'table' or type(decoded.files) ~= 'table' then
    return {
      files = {},
    }
  end

  ---@cast decoded GamesExportManifest

  return decoded
end

---@param path string
---@param manifest GamesExportManifest
local function write_export_manifest(path, manifest)
  assert(type(path) == 'string' and path ~= '')
  assert(type(manifest) == 'table')
  assert(type(manifest.files) == 'table')

  local encoded = json.encode(manifest)
  local file, open_error = io.open(path, 'w')

  if file == nil then
    error(
      'games.shared.godot_engine: could not open export manifest for write: ' .. path .. ': ' .. tostring(open_error)
    )
  end

  local write_ok, write_error = file:write(encoded)

  if not write_ok then
    file:close()
    error('games.shared.godot_engine: could not write export manifest: ' .. path .. ': ' .. tostring(write_error))
  end

  local close_ok, close_error = file:close()

  if not close_ok then
    error('games.shared.godot_engine: could not close export manifest: ' .. path .. ': ' .. tostring(close_error))
  end
end

---@param root string
---@return table<string, string>
---@return integer
local function collect_export_mtimes(root)
  assert(type(root) == 'string' and root ~= '')

  local files = {}
  local entry_counter = { 0 }

  scan_export_relevant_files(root, files, entry_counter, 0)

  ---@type table<string, string>
  local mtimes = {}

  for index = 1, #files do
    local path = files[index]
    local stat = uv.fs_stat(path)

    if stat ~= nil then
      local mtime_key = stat_mtime_key(stat)

      if mtime_key ~= nil then
        mtimes[path] = mtime_key
      end
    end
  end

  return mtimes, entry_counter[1]
end

---@param path string
---@param root string
---@return string?
local function project_relative_path(path, root)
  assert(type(path) == 'string' and path ~= '')
  assert(type(root) == 'string' and root ~= '')

  local normalized_path = normalize(path)
  local normalized_root = normalize(root)
  local prefix = normalized_root .. '/'

  if normalized_path:sub(1, #prefix) ~= prefix then
    return nil
  end

  local relative = normalized_path:sub(#prefix + 1)

  if relative == '' then
    return nil
  end

  return relative
end

---@param opts GamesGodotEngineOptions
---@return table
function M.new(opts)
  assert(type(opts) == 'table')
  assert(type(opts.name) == 'string' and opts.name ~= '')

  local engine = {}

  local name = opts.name
  local command_prefix = opts.command_prefix or name
  local leader = opts.leader or '<leader>gg'
  local binaries = opts.binaries or { name:lower() }
  local env_names = opts.env_names or { name:upper() .. '_BIN' }
  local root_markers = opts.root_markers or { 'project.godot' }
  local output_filetype = opts.output_filetype or (name:lower() .. '-output')

  assert(type(command_prefix) == 'string' and command_prefix ~= '')
  assert(type(leader) == 'string' and leader ~= '')
  assert(type(binaries) == 'table' and #binaries > 0)
  assert(type(env_names) == 'table' and #env_names > 0)
  assert(type(root_markers) == 'table' and #root_markers > 0)
  assert(type(output_filetype) == 'string' and output_filetype ~= '')

  local output = output_factory.new(output_filetype)

  engine.name = name
  engine.config = {
    group_order = {
      'Editor',
      'Run',
      'Export',
      'Debug',
      'Project',
    },
    output_filetype = output_filetype,
  }

  local util = {}
  engine.util = util

  function util.find_binary()
    local override = shared_util.env_first(env_names)

    if override ~= nil then
      local resolved = shared_util.first_executable({
        override,
      })

      if resolved ~= nil then
        return resolved
      end

      game_notify(name .. ': configured binary is not executable: ' .. override, levels.WARN)
    end

    return shared_util.first_executable(binaries)
  end

  function util.find_root(start_dir)
    return shared_util.find_root(root_markers, start_dir)
  end

  function util.require_binary()
    local binary = util.find_binary()

    if binary == nil then
      game_notify(
        string.format(
          '%s executable not found. Set %s or add one of {%s} to $PATH.',
          name,
          table.concat(env_names, ' / '),
          table.concat(binaries, ', ')
        ),
        levels.ERROR
      )
    end

    return binary
  end

  function util.require_root()
    local root = util.find_root()

    if root == nil then
      game_notify(
        name .. ': no ' .. table.concat(root_markers, ' / ') .. ' found upward from the current working directory.',
        levels.ERROR
      )
    end

    return root
  end

  local actions = {}
  engine.actions = actions

  function actions.open_editor()
    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    if start_detached({
      binary,
      '--editor',
      '--path',
      root,
    }, name .. ' editor') then
      game_notify(name .. ': editor launching for ' .. root)
    end
  end

  function actions.open_project_manager()
    local binary = util.require_binary()

    if binary == nil then
      return
    end

    if start_detached({
      binary,
      '--project-manager',
    }, name .. ' project manager') then
      game_notify(name .. ': project manager launching.')
    end
  end

  function actions.run_project()
    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    if start_detached({
      binary,
      '--path',
      root,
    }, name .. ' project') then
      game_notify(name .. ': running project at ' .. root)
    end
  end

  function actions.run_current_scene()
    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    local file = api.nvim_buf_get_name(0)

    if file == '' or not file:match('%.tscn$') then
      game_notify(name .. ': the current buffer is not a .tscn scene.', levels.WARN)
      return
    end

    local relative = project_relative_path(file, root)

    if relative == nil then
      game_notify(name .. ': current scene is outside the detected project root.', levels.WARN)
      return
    end

    if start_detached({
      binary,
      '--path',
      root,
      relative,
    }, name .. ' current scene') then
      game_notify(name .. ': running scene ' .. relative)
    end
  end

  function actions.check_current_script()
    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    local file = api.nvim_buf_get_name(0)

    if file == '' or not file:match('%.gd$') then
      game_notify(name .. ': the current buffer is not a .gd script.', levels.WARN)
      return
    end

    output.run_with_progress(command_prefix .. 'Check', 'Checking ' .. fs.basename(file), {
      binary,
      '--headless',
      '--path',
      root,
      '--check-only',
      '--script',
      file,
    }, {
      cwd = root,
      failure = 'Parse errors found.',
      show_output = true,
      success = 'No parse errors.',
    })
  end

  ---@param preset_kind string
  ---@param export_flag string
  local function export(preset_kind, export_flag)
    assert(type(preset_kind) == 'string' and preset_kind ~= '')
    assert(type(export_flag) == 'string' and export_flag ~= '')

    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    local preset = prompt_nonempty(name .. ' export preset: ', '')

    if preset == nil then
      return
    end

    local output_input = prompt_nonempty(name .. ' export output path: ', root .. '/build/', 'file')

    if output_input == nil then
      return
    end

    local output_path = normalize(output_input)

    if output_path == '' then
      game_notify(name .. ': export output path is invalid.', levels.WARN)
      return
    end

    local output_directory = fs.dirname(output_path)

    if type(output_directory) ~= 'string' or output_directory == '' then
      game_notify(name .. ': could not determine the export output directory.', levels.ERROR)
      return
    end

    local mkdir_result = fn.mkdir(output_directory, 'p')

    if mkdir_result ~= 1 and not is_directory(output_directory) then
      game_notify(name .. ': could not create export directory: ' .. output_directory, levels.ERROR)
      return
    end

    output.run_with_progress(command_prefix .. preset_kind, 'Exporting (' .. preset_kind .. ') ' .. preset, {
      binary,
      '--headless',
      '--path',
      root,
      export_flag,
      preset,
      output_path,
    }, {
      cwd = root,
      failure = 'Export failed.',
      show_output = true,
      success = 'Export finished: ' .. output_path,
      on_success = function()
        local files, entry_count = collect_export_mtimes(root)

        if entry_count >= EXPORT_SCAN_MAX_ENTRIES then
          game_notify(
            string.format(
              '%s: export baseline reached EXPORT_SCAN_MAX_ENTRIES=%d; it may be incomplete.',
              name,
              EXPORT_SCAN_MAX_ENTRIES
            ),
            levels.WARN
          )
        end

        write_export_manifest(export_manifest_path(name), {
          files = files,
          saved_at = os.time(),
        })

        events.fire_task_result(name:lower(), 'export_' .. preset_kind:lower(), true, {
          output_path = output_path,
        })
      end,
      on_failure = function()
        events.fire_task_result(name:lower(), 'export_' .. preset_kind:lower(), false, {
          output_path = output_path,
        })
      end,
    })
  end

  function actions.export_release()
    export('ExportRelease', '--export-release')
  end

  function actions.export_debug()
    export('ExportDebug', '--export-debug')
  end

  function actions.export_dry_run()
    local root = util.require_root()

    if root == nil then
      return
    end

    local manifest_path = export_manifest_path(name)
    local previous = read_export_manifest(manifest_path)
    local current, entry_count = collect_export_mtimes(root)

    if entry_count >= EXPORT_SCAN_MAX_ENTRIES then
      game_notify(
        string.format(
          '%s: directory scan reached EXPORT_SCAN_MAX_ENTRIES=%d; report may be incomplete.',
          name,
          EXPORT_SCAN_MAX_ENTRIES
        ),
        levels.WARN
      )
    end

    ---@type string[]
    local changed = {}

    for path, mtime_key in pairs(current) do
      if previous.files[path] ~= mtime_key then
        changed[#changed + 1] = path
      end
    end

    table.sort(changed)

    if #changed == 0 then
      game_notify(name .. ': dry-run found no changed .tscn/.gd/.import files since the last recorded export.')
      return
    end

    local quickfix_items = {}

    for index = 1, #changed do
      quickfix_items[#quickfix_items + 1] = {
        filename = changed[index],
        text = 'changed since last ' .. name .. ' export',
      }
    end

    fn.setqflist({}, 'r', {
      items = quickfix_items,
      title = name .. ' export dry-run',
    })

    vim.cmd('copen')

    game_notify(string.format('%s: %d file(s) changed since the last export; see quickfix.', name, #changed))
  end

  function actions.remote_debug_launch()
    local binary = util.require_binary()
    local root = util.require_root()

    if binary == nil or root == nil then
      return
    end

    local port = prompt_integer_in_range(
      name .. ' remote-debug port (editor must already be listening): ',
      DEFAULT_REMOTE_DEBUG_PORT,
      1,
      65535
    )

    if port == nil then
      game_notify(name .. ': remote-debug port must be an integer from 1 through 65535.', levels.WARN)
      return
    end

    local endpoint = string.format('tcp://%s:%d', DEFAULT_REMOTE_DEBUG_HOST, port)

    if
      start_detached({
        binary,
        '--path',
        root,
        '--remote-debug',
        endpoint,
      }, name .. ' remote-debug target')
    then
      game_notify(
        string.format(
          '%s: launched with --remote-debug %s. Open Debugger > Remote in a listening %s editor.',
          name,
          endpoint,
          name
        )
      )
    end
  end

  function actions.describe_project()
    local root = util.find_root()
    local binary = util.find_binary()

    game_notify(table.concat({
      name .. ' project root: ' .. (root or 'not found'),
      name .. ' binary: ' .. (binary or 'not found'),
    }, '\n'))
  end

  function actions.get_actions()
    return {
      {
        group = 'Editor',
        id = 'open_editor',
        label = 'Open editor',
        run = actions.open_editor,
      },
      {
        group = 'Editor',
        id = 'open_project_manager',
        label = 'Open project manager',
        run = actions.open_project_manager,
      },
      {
        group = 'Run',
        id = 'run_project',
        label = 'Run project',
        run = actions.run_project,
      },
      {
        group = 'Run',
        id = 'run_current_scene',
        label = 'Run current scene',
        run = actions.run_current_scene,
      },
      {
        group = 'Run',
        id = 'check_current_script',
        label = 'Check current script (parse only)',
        run = actions.check_current_script,
      },
      {
        group = 'Export',
        id = 'export_release',
        label = 'Export release',
        run = actions.export_release,
      },
      {
        group = 'Export',
        id = 'export_debug',
        label = 'Export debug',
        run = actions.export_debug,
      },
      {
        group = 'Export',
        id = 'export_dry_run',
        label = 'Export dry-run (changed-file report)',
        run = actions.export_dry_run,
      },
      {
        group = 'Debug',
        id = 'remote_debug_launch',
        label = 'Launch with --remote-debug (not DAP)',
        run = actions.remote_debug_launch,
      },
      {
        group = 'Project',
        id = 'describe_project',
        label = 'Describe project',
        run = actions.describe_project,
      },
    }
  end

  ---@param action { run: fun() }
  function actions.run_action(action)
    assert(type(action) == 'table')
    assert(type(action.run) == 'function')

    action.run()
  end

  ---@param id string
  function actions.run_action_by_id(id)
    assert(type(id) == 'string' and id ~= '')

    local action_map = shared_util.build_action_map(actions.get_actions())
    local action = action_map[id]

    if action == nil then
      game_notify('Unknown ' .. name .. ' action: ' .. id, levels.ERROR)
      return
    end

    actions.run_action(action)
  end

  function actions.show_menu()
    shared_ui.select_root_menu(actions.get_actions(), actions.run_action, {
      group_order = engine.config.group_order,
      prompt = 'Select ' .. name .. ' action:',
    })
  end

  local commands = {}
  engine.commands = commands

  function commands.setup_commands()
    local action_list = actions.get_actions()

    api.nvim_create_user_command(command_prefix, function()
      actions.show_menu()
    end, {
      desc = 'Open ' .. name .. ' action menu',
    })

    api.nvim_create_user_command(command_prefix .. 'Action', function(command_options)
      actions.run_action_by_id(command_options.args)
    end, {
      complete = function(argument_lead)
        return shared_util.get_action_ids(action_list, argument_lead)
      end,
      desc = 'Run a ' .. name .. ' action by ID',
      nargs = 1,
    })

    for index = 1, #action_list do
      local action = action_list[index]
      local command_name = command_prefix .. shared_util.snake_to_pascal(action.id)

      api.nvim_create_user_command(command_name, function()
        actions.run_action(action)
      end, {
        desc = action.label,
      })
    end
  end

  function commands.setup_keymaps()
    local function key(suffix)
      assert(type(suffix) == 'string' and suffix ~= '')

      return leader .. suffix
    end

    vim.keymap.set('n', key('e'), actions.open_editor, {
      desc = name .. ': Open editor',
    })

    vim.keymap.set('n', key('p'), actions.open_project_manager, {
      desc = name .. ': Open project manager',
    })

    vim.keymap.set('n', key('r'), actions.run_project, {
      desc = name .. ': Run project',
    })

    vim.keymap.set('n', key('s'), actions.run_current_scene, {
      desc = name .. ': Run current scene',
    })

    vim.keymap.set('n', key('c'), actions.check_current_script, {
      desc = name .. ': Check current script',
    })

    vim.keymap.set('n', key('x'), actions.export_release, {
      desc = name .. ': Export release',
    })

    vim.keymap.set('n', key('d'), actions.export_debug, {
      desc = name .. ': Export debug',
    })

    vim.keymap.set('n', key('y'), actions.export_dry_run, {
      desc = name .. ': Export dry-run (changed files)',
    })

    vim.keymap.set('n', key('b'), actions.remote_debug_launch, {
      desc = name .. ': Launch native remote-debug target',
    })
  end

  function engine.setup()
    commands.setup_commands()
    commands.setup_keymaps()
  end

  engine.show_menu = actions.show_menu
  engine.run_action_by_id = actions.run_action_by_id

  return engine
end
return M
