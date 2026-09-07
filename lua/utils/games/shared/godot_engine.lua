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
-- Shared native-tooling factory for Godot and Godot-compatible forks
-- (currently Godot 4 and Redot 4, which retain project.godot / .tscn /
-- .gd file compatibility). Each fork gets its own isolated module by
-- calling M.new(opts) with its own binary candidates and keymap prefix,
-- so the two engines never share cached state or output windows.
local shared_util = require('utils.games.shared.util')
local shared_ui = require('utils.games.shared.ui')
local output_factory = require('utils.games.shared.output')
local events = require('utils.games.shared.events')

local notify = vim.notify
local levels = vim.log.levels
local uv = vim.uv or vim.loop

local M = {}

-- Fixed, explicit bounds for the export-manifest directory walk
-- (Tiger Style: a recursive scan without a hard ceiling is the Lua
-- equivalent of `find /` with no `-maxdepth` -- fine on a small
-- project, a real problem on someone's home-lab NAS mount). These
-- are generous enough for any real Godot/Redot project and cheap
-- enough to keep a dry-run feeling instant.
local EXPORT_SCAN_MAX_DEPTH = 16
local EXPORT_SCAN_MAX_ENTRIES = 20000

-- Directories that hold generated/cache data rather than source --
-- walking into them would make every dry-run report "everything
-- changed" after any build, the same way `rsync`-ing a `.git/` or a
-- `node_modules/` tree produces noise nobody wants to diff.
local EXPORT_SCAN_IGNORED_DIRS = { ['.git'] = true, ['.import'] = true, ['.godot'] = true, ['.mono'] = true }

-- File extensions that actually affect an export's output: scenes,
-- scripts, and Godot's per-asset import metadata (a changed .import
-- means the asset pipeline will re-bake something even if the
-- source asset itself is unchanged).
local EXPORT_SCAN_RELEVANT_EXTENSIONS = { tscn = true, gd = true, import = true }

---@param root string
---@param out_files string[]  appended in place
---@param entry_counter integer[]  single-element counter cell (Lua has no `inout` params)
---@param depth integer
local function scan_export_relevant_files(root, out_files, entry_counter, depth)
  assert(type(root) == 'string' and root ~= '', 'games.shared.godot_engine: scan root is required')
  assert(
    depth <= EXPORT_SCAN_MAX_DEPTH,
    ('games.shared.godot_engine: directory nesting exceeded EXPORT_SCAN_MAX_DEPTH=%d at %s'):format(
      EXPORT_SCAN_MAX_DEPTH,
      root
    )
  )

  local handle = uv.fs_scandir(root)
  if not handle then
    return
  end

  while entry_counter[1] <= EXPORT_SCAN_MAX_ENTRIES do
    local entry_name, entry_type = uv.fs_scandir_next(handle)
    if not entry_name then
      return
    end
    entry_counter[1] = entry_counter[1] + 1

    local full_path = root .. '/' .. entry_name
    if entry_type == 'directory' then
      if not EXPORT_SCAN_IGNORED_DIRS[entry_name] then
        scan_export_relevant_files(full_path, out_files, entry_counter, depth + 1)
      end
    else
      local extension = entry_name:match('%.([%w]+)$')
      if extension and EXPORT_SCAN_RELEVANT_EXTENSIONS[extension] then
        out_files[#out_files + 1] = full_path
      end
    end
  end
end

---@param engine_name string
---@return string
local function export_manifest_path(engine_name)
  local state_dir = vim.fn.stdpath('state') .. '/games-nvim'
  vim.fn.mkdir(state_dir, 'p')
  return state_dir .. '/' .. engine_name:lower() .. '-export-state.json'
end

---@param path string
---@return table  always a table with a `files` field, even on read failure
local function read_export_manifest(path)
  local ok, contents = pcall(shared_util.read_file, path)
  if not ok or contents == nil or contents == '' then
    return { files = {} }
  end
  local decode_ok, decoded = pcall(vim.json.decode, contents)
  if not decode_ok or type(decoded) ~= 'table' or type(decoded.files) ~= 'table' then
    return { files = {} }
  end
  return decoded
end

---@param path string
---@param manifest table
local function write_export_manifest(path, manifest)
  assert(type(manifest) == 'table' and type(manifest.files) == 'table', 'games.shared.godot_engine: manifest.files is required')
  local encoded = vim.json.encode(manifest)
  local file = assert(io.open(path, 'w'), 'games.shared.godot_engine: could not open manifest for write: ' .. path)
  file:write(encoded)
  file:close()
end

---@param opts table
---  name          display name, e.g. "Godot" or "Redot"
---  command_prefix    user command prefix, e.g. "Godot" or "Redot"
---  leader        keymap group prefix, e.g. "<leader>gg" or "<leader>gr"
---  binaries      ordered list of executable name candidates
---  env_names     ordered list of env var names for an explicit override
---  root_markers  project root marker files (default {'project.godot'})
function M.new(opts)
  assert(opts and opts.name, 'games.shared.godot_engine: opts.name is required')

  local engine = {}
  local name = opts.name
  local command_prefix = opts.command_prefix or name
  local leader = opts.leader or '<leader>gg'
  local binaries = opts.binaries or { name:lower() }
  local env_names = opts.env_names or { name:upper() .. '_BIN' }
  local root_markers = opts.root_markers or { 'project.godot' }
  local output_filetype = (opts.output_filetype or (name:lower() .. '-output'))

  local output = output_factory.new(output_filetype)

  local config = {
    output_filetype = output_filetype,
    group_order = { 'Editor', 'Run', 'Export', 'Debug', 'Project' },
  }
  engine.config = config
  -- Exposed so callers (e.g. health.lua's GamesDoctor probes) can
  -- label a report row without re-deriving "Godot" vs "Redot" from
  -- the module path -- one source of truth for the display name.
  engine.name = name

  local util = {}
  engine.util = util

  function util.find_binary()
    local override = shared_util.env_first(env_names)
    if override then
      local resolved = shared_util.first_executable({ override })
      if resolved then
        return resolved
      end
      notify(name .. ': configured binary is not executable: ' .. override, levels.WARN)
    end
    return shared_util.first_executable(binaries)
  end

  function util.find_root(start_dir)
    return shared_util.find_root(root_markers, start_dir)
  end

  function util.require_binary()
    local bin = util.find_binary()
    if not bin then
      notify(
        string.format(
          '%s executable not found. Set %s or add one of {%s} to $PATH.',
          name,
          table.concat(env_names, ' / '),
          table.concat(binaries, ', ')
        ),
        levels.ERROR
      )
    end
    return bin
  end

  function util.require_root()
    local root = util.find_root()
    if not root then
      notify(name .. ': no ' .. table.concat(root_markers, '/') .. ' found upward from cwd.', levels.ERROR)
    end
    return root
  end

  local actions = {}
  engine.actions = actions

  function actions.open_editor()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    vim.fn.jobstart({ bin, '--editor', '--path', root }, { detach = true })
    notify(name .. ': editor launching for ' .. root, levels.INFO)
  end

  function actions.open_project_manager()
    local bin = util.require_binary()
    if not bin then
      return
    end
    vim.fn.jobstart({ bin, '--project-manager' }, { detach = true })
    notify(name .. ': project manager launching', levels.INFO)
  end

  function actions.run_project()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    vim.fn.jobstart({ bin, '--path', root }, { detach = true })
    notify(name .. ': running project at ' .. root, levels.INFO)
  end

  function actions.run_current_scene()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    if file == '' or not file:match('%.tscn$') then
      notify(name .. ': current buffer is not a .tscn scene', levels.WARN)
      return
    end
    local relative = file:sub(#root + 2)
    vim.fn.jobstart({ bin, '--path', root, relative }, { detach = true })
    notify(name .. ': running scene ' .. relative, levels.INFO)
  end

  function actions.check_current_script()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local file = vim.api.nvim_buf_get_name(0)
    if file == '' or not file:match('%.gd$') then
      notify(name .. ': current buffer is not a .gd script', levels.WARN)
      return
    end
    output.run_with_progress(
      command_prefix .. 'Check',
      'Checking ' .. vim.fs.basename(file),
      { bin, '--headless', '--path', root, '--check-only', '--script', file },
      {
        show_output = true,
        success = 'No parse errors.',
        failure = 'Parse errors found.',
        cwd = root,
      }
    )
  end

  local function export(preset_kind, flag)
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end
    local preset = shared_util.trim(vim.fn.input(name .. ' export preset: '))
    if preset == '' then
      return
    end
    local output_path = shared_util.trim(
      vim.fn.input(name .. ' export output path: ', root .. '/build/', 'file')
    )
    if output_path == '' then
      return
    end
    vim.fn.mkdir(vim.fs.dirname(output_path), 'p')
    output.run_with_progress(
      command_prefix .. preset_kind,
      'Exporting (' .. preset_kind .. ') ' .. preset,
      { bin, '--headless', '--path', root, flag, preset, output_path },
      {
        show_output = true,
        success = 'Export finished: ' .. output_path,
        failure = 'Export failed.',
        cwd = root,
        -- Refreshes the dry-run baseline on every SUCCESSFUL export so
        -- the next `export_dry_run` call reports "no changes" until a
        -- source file is touched again -- the same idea as a `make`
        -- target's own outputs updating the mtimes it will compare
        -- against next time, kept correct without asking the user to
        -- remember a separate "mark as exported" step.
        on_success = function()
          local files = {}
          local entry_counter = { 0 }
          scan_export_relevant_files(root, files, entry_counter, 0)
          local current = {}
          for _, path in ipairs(files) do
            local stat = uv.fs_stat(path)
            if stat then
              current[path] = stat.mtime.sec
            end
          end
          write_export_manifest(export_manifest_path(name), { files = current, saved_at = os.time() })

          -- Fire the shared `User GamesTaskCompleted` event (see
          -- shared/events.lua for why this uses a plain `User`
          -- autocmd rather than CmdAtom) so anything else in your
          -- config -- a statusline, a notification aggregator, a
          -- future plugin -- can react to "an export just finished"
          -- without this module needing to know it exists.
          events.fire_task_result(name:lower(), 'export_' .. preset_kind:lower(), true, { output_path = output_path })
        end,
        on_failure = function()
          events.fire_task_result(name:lower(), 'export_' .. preset_kind:lower(), false, { output_path = output_path })
        end,
      }
    )
  end

  function actions.export_release()
    export('ExportRelease', '--export-release')
  end

  function actions.export_debug()
    export('ExportDebug', '--export-debug')
  end

  function actions.describe_project()
    local root = util.find_root()
    local bin = util.find_binary()
    notify(
      table.concat({
        name .. ' project root: ' .. (root or 'not found'),
        name .. ' binary: ' .. (bin or 'not found'),
      }, '\n'),
      levels.INFO
    )
  end

  -- TODO (README): "--dry-run scene diff before export".
  --
  -- WHY mtimes instead of a real content diff: a byte-for-byte diff
  -- of binary .import cache files would be noisy and slow for no
  -- benefit -- the question a developer actually has before kicking
  -- off a multi-minute export is "did ANY export-relevant file
  -- change since I last exported", which mtime comparison answers
  -- correctly and near-instantly. This is the same tradeoff `make`
  -- makes when it uses mtimes instead of hashing every source file.
  function actions.export_dry_run()
    local root = util.require_root()
    if not root then
      return
    end

    local manifest_path = export_manifest_path(name)
    local previous = read_export_manifest(manifest_path)

    local files = {}
    local entry_counter = { 0 }
    scan_export_relevant_files(root, files, entry_counter, 0)
    if entry_counter[1] > EXPORT_SCAN_MAX_ENTRIES then
      notify(
        string.format(
          '%s: directory scan stopped after EXPORT_SCAN_MAX_ENTRIES=%d entries; report may be incomplete.',
          name,
          EXPORT_SCAN_MAX_ENTRIES
        ),
        levels.WARN
      )
    end

    local changed = {}
    for _, path in ipairs(files) do
      local stat = uv.fs_stat(path)
      if stat then
        local previous_mtime = previous.files[path]
        if previous_mtime == nil or previous_mtime ~= stat.mtime.sec then
          changed[#changed + 1] = path
        end
      end
    end
    table.sort(changed)

    if #changed == 0 then
      notify(name .. ': dry-run found no changed .tscn/.gd/.import files since the last recorded export.', levels.INFO)
      return
    end

    local quickfix_items = {}
    for _, path in ipairs(changed) do
      quickfix_items[#quickfix_items + 1] = { filename = path, text = 'changed since last ' .. name .. ' export' }
    end
    vim.fn.setqflist(quickfix_items, 'r')
    vim.cmd('copen')
    notify(
      string.format('%s: %d file(s) changed since last export (see quickfix).', name, #changed),
      levels.INFO
    )
  end

  -- TODO (README): "DAP wiring alongside the existing GDScript LSP".
  --
  -- HONEST SCOPE NOTE (do not skip reading this if you're extending
  -- this file): Unreal exposes `lua/dap/unreal.lua` because Unreal's
  -- C++ layer talks to lldb-dap/GDB over the real Debug Adapter
  -- Protocol -- a general-purpose, language-server-shaped debug
  -- protocol, the same category of thing as an LSP but for stepping
  -- through code instead of completing it. Godot 4 (and Redot 4)
  -- ship NO general-purpose DAP server. Their actual remote-debugging
  -- mechanism is `--remote-debug tcp://host:port`: the exported/run
  -- build opens a TCP connection back to a *listening Godot editor
  -- instance* and speaks Godot's own internal debug wire protocol,
  -- not DAP. Faking a `lua/dap/godot.lua` that pretends to be a DAP
  -- adapter here would be actively misleading, so we do not ship one.
  -- What we CAN honestly offer is a one-key launcher for that real
  -- mechanism -- the equivalent of a documented `ssh -R` reverse
  -- tunnel helper rather than a fake protocol shim.
  function actions.remote_debug_launch()
    local bin, root = util.require_binary(), util.require_root()
    if not bin or not root then
      return
    end

    local port_input = shared_util.trim(
      vim.fn.input(name .. ' remote-debug port (editor must already be listening): ', '6007')
    )
    if port_input == '' then
      return
    end
    local port = tonumber(port_input)
    assert(port ~= nil and port > 0 and port < 65536, 'games.' .. name:lower() .. ': port must be a number between 1 and 65535')

    vim.fn.jobstart({ bin, '--path', root, '--remote-debug', ('tcp://127.0.0.1:%d'):format(port) }, { detach = true })
    notify(
      string.format(
        '%s: launched with --remote-debug tcp://127.0.0.1:%d -- open Debugger > Remote in a running %s editor first.',
        name,
        port,
        name
      ),
      levels.INFO
    )
  end

  function actions.get_actions()
    return {
      { id = 'open_editor', label = 'Open editor', group = 'Editor', run = actions.open_editor },
      { id = 'open_project_manager', label = 'Open project manager', group = 'Editor', run = actions.open_project_manager },
      { id = 'run_project', label = 'Run project', group = 'Run', run = actions.run_project },
      { id = 'run_current_scene', label = 'Run current scene', group = 'Run', run = actions.run_current_scene },
      { id = 'check_current_script', label = 'Check current script (parse only)', group = 'Run', run = actions.check_current_script },
      { id = 'export_release', label = 'Export release', group = 'Export', run = actions.export_release },
      { id = 'export_debug', label = 'Export debug', group = 'Export', run = actions.export_debug },
      { id = 'export_dry_run', label = 'Export dry-run (changed-file report)', group = 'Export', run = actions.export_dry_run },
      { id = 'remote_debug_launch', label = 'Launch with --remote-debug (not DAP)', group = 'Debug', run = actions.remote_debug_launch },
      { id = 'describe_project', label = 'Describe project', group = 'Project', run = actions.describe_project },
    }
  end

  function actions.run_action(action)
    action.run()
  end

  function actions.run_action_by_id(id)
    local list = actions.get_actions()
    local map = shared_util.build_action_map(list)
    local action = map[id]
    if not action then
      notify('Unknown ' .. name .. ' action: ' .. id, levels.ERROR)
      return
    end
    actions.run_action(action)
  end

  function actions.show_menu()
    shared_ui.select_root_menu(actions.get_actions(), actions.run_action, {
      group_order = config.group_order,
      prompt = 'Select ' .. name .. ' action:',
    })
  end

  local commands = {}
  engine.commands = commands

  function commands.setup_commands()
    local action_list = actions.get_actions()

    vim.api.nvim_create_user_command(command_prefix, function()
      actions.show_menu()
    end, { desc = 'Open ' .. name .. ' action menu' })

    vim.api.nvim_create_user_command(command_prefix .. 'Action', function(cmd_opts)
      actions.run_action_by_id(cmd_opts.args)
    end, {
      nargs = 1,
      complete = function(arg_lead)
        return shared_util.get_action_ids(action_list, arg_lead)
      end,
      desc = 'Run a ' .. name .. ' action by id',
    })

    for i = 1, #action_list do
      local action = action_list[i]
      local cmd_name = command_prefix .. shared_util.snake_to_pascal(action.id)
      vim.api.nvim_create_user_command(cmd_name, function()
        actions.run_action(action)
      end, { desc = action.label })
    end
  end

  function commands.setup_keymaps()
    local map = vim.keymap.set
    local function key(suffix)
      return leader .. suffix
    end

    map('n', key('e'), actions.open_editor, { desc = name .. ': Open editor' })
    map('n', key('p'), actions.open_project_manager, { desc = name .. ': Open project manager' })
    map('n', key('r'), actions.run_project, { desc = name .. ': Run project' })
    map('n', key('s'), actions.run_current_scene, { desc = name .. ': Run current scene' })
    map('n', key('c'), actions.check_current_script, { desc = name .. ': Check current script' })
    map('n', key('x'), actions.export_release, { desc = name .. ': Export release' })
    map('n', key('d'), actions.export_debug, { desc = name .. ': Export debug' })
    map('n', key('y'), actions.export_dry_run, { desc = name .. ': Export dry-run (changed files)' })
    map('n', key('b'), actions.remote_debug_launch, { desc = name .. ': Launch with --remote-debug' })
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
