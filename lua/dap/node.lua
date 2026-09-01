-- #################################################################
-- ~/.config/nvim/lua/dap/node.lua
-- Qompass AI Diver Native JavaScript/TypeScript Debug Configuration
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
---@source https://github.com/microsoft/vscode-js-debug
---@source https://github.com/microsoft/vscode-js-debug/blob/main/OPTIONS.md
---@source https://github.com/microsoft/vscode-js-debug/blob/main/src/dapDebugServer.ts

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local SOURCE = 'js-debug'
local DEFAULT_BROWSER_PORT = 9222
local DEFAULT_NODE_PORT = 9229
local DEFAULT_URL = 'http://localhost:3000'

---@type string[]
local ROOT_MARKERS = {
  'package.json',
  'pnpm-lock.yaml',
  'yarn.lock',
  'package-lock.json',
  'bun.lock',
  'bun.lockb',
  'deno.json',
  'deno.jsonc',
  'tsconfig.json',
  'jsconfig.json',
  'vite.config.js',
  'vite.config.ts',
  'webpack.config.js',
  'webpack.config.ts',
  'ember-cli-build.js',
  '.git',
}

---@type string[]
local SERVER_RELATIVE_PATHS = {
  'out/src/dapDebugServer.js',
  'dist/src/dapDebugServer.js',
  'src/dapDebugServer.js',
  'dapDebugServer.js',
}

---@type string[]
local VSCODE_EXTENSION_ROOTS = {
  fs.joinpath(
    fn.expand('~'),
    '.vscode',
    'extensions'
  ),

  fs.joinpath(
    fn.expand('~'),
    '.vscode-oss',
    'extensions'
  ),

  fs.joinpath(
    fn.expand('~'),
    '.var',
    'app',
    'com.visualstudio.code',
    'data',
    'vscode',
    'extensions'
  ),
}

---@type table<string, boolean>
local TYPESCRIPT_FILETYPES = {
  typescript = true,
  typescriptreact = true,
  ['typescript.glimmer'] = true,
}

---@class JsDebugState
---@field adapter string?
---@field root string?
local state = {
  adapter = nil,
  root = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(
    ('[%s] %s'):format(
      SOURCE,
      message
    ),
    level or levels.INFO
  )
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == 'string'
    and value ~= ''
end

---@param path string
---@return boolean
local function readable_file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == 'file'
end

---@param path string
---@return boolean
local function directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == 'directory'
end

---@param path string
---@return string
local function normalize(path)
  if path == '' then
    return ''
  end

  return fs.normalize(
    fn.fnamemodify(path, ':p')
  )
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
  bufnr = bufnr
    or api.nvim_get_current_buf()

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
local function filetype(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ''
  end

  return vim.bo[bufnr].filetype
end

---@param bufnr? integer
---@return string
local function project_root(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local current_filename = filename(bufnr)

  if current_filename ~= '' then
    local detected = fs.root(
      current_filename,
      ROOT_MARKERS
    )

    if
      type(detected) == 'string'
      and detected ~= ''
    then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(
      current_filename
    )

    if
      type(parent) == 'string'
      and parent ~= ''
    then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(
    fn.getcwd()
  )
end

---@param root string
---@return string?
local function adapter_from_root(root)
  if not directory(root) then
    return nil
  end

  for _, relative in ipairs(
    SERVER_RELATIVE_PATHS
  ) do
    local candidate = fs.joinpath(
      root,
      relative
    )

    if readable_file(candidate) then
      return fs.normalize(candidate)
    end
  end

  return nil
end

---@param root string
---@return string?
local function adapter_from_extension_root(root)
  if not directory(root) then
    return nil
  end

  local handle = uv.fs_scandir(root)

  if handle == nil then
    return nil
  end

  ---@type string[]
  local matches = {}

  while true do
    local name, entry_type = uv.fs_scandir_next(
      handle
    )

    if name == nil then
      break
    end

    if
      entry_type == 'directory'
      and (
        name:match(
          '^ms%-vscode%.js%-debug%-'
        )
        or name:match(
          '^ms%-vscode%.js%-debug%-nightly%-'
        )
      )
    then
      matches[#matches + 1] = name
    end
  end

  table.sort(
    matches,
    function(left, right)
      return left > right
    end
  )

  for _, name in ipairs(matches) do
    local extension = fs.joinpath(
      root,
      name
    )

    local candidate = adapter_from_root(
      extension
    )

    if candidate ~= nil then
      return candidate
    end
  end

  return nil
end

---@return string?
local function resolve_adapter()
  if
    state.adapter ~= nil
    and readable_file(state.adapter)
  then
    return state.adapter
  end

  --
  -- Direct path to dapDebugServer.js.
  --
  local direct = vim.env.NVIM_JS_DEBUG_ADAPTER

  if nonempty_string(direct) then
    local candidate = normalize(
      fn.expand(direct)
    )

    if readable_file(candidate) then
      state.adapter = candidate

      return candidate
    end

    notify(
      (
        'NVIM_JS_DEBUG_ADAPTER is not readable: %s'
      ):format(candidate),
      levels.WARN
    )
  end

  --
  -- Root of a standalone vscode-js-debug build.
  --
  local configured_root =
    vim.env.NVIM_JS_DEBUG_ROOT

  if nonempty_string(configured_root) then
    local candidate = adapter_from_root(
      normalize(
        fn.expand(configured_root)
      )
    )

    if candidate ~= nil then
      state.adapter = candidate

      return candidate
    end
  end

  --
  -- Fall back to installed VS Code extension bundles.
  --
  for _, root in ipairs(
    VSCODE_EXTENSION_ROOTS
  ) do
    local candidate =
      adapter_from_extension_root(root)

    if candidate ~= nil then
      state.adapter = candidate

      return candidate
    end
  end

  return nil
end

---@return string
local function required_adapter()
  local adapter = resolve_adapter()

  if adapter ~= nil then
    return adapter
  end

  return '/nonexistent/qompass-js-debug/dapDebugServer.js'
end

---@return string
local function node()
  return executable_path('node')
    or 'node'
end

---@return string
local function current_file()
  local current = filename()

  if current ~= '' then
    return current
  end

  return '${file}'
end

---@return string
local function cwd()
  local root = project_root()

  state.root = root

  return root
end

---@return string[]
local function prompt_args()
  local input = fn.input(
    'Program arguments: '
  )

  if input == '' then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string
local function prompt_url()
  local value = fn.input(
    'Browser URL: ',
    DEFAULT_URL
  )

  if value == '' then
    return DEFAULT_URL
  end

  return value
end

---@param prompt string
---@param default integer
---@return integer
local function prompt_port(prompt, default)
  local input = fn.input(
    prompt,
    tostring(default)
  )

  local value = tonumber(input)

  if
    value == nil
    or value < 1
    or value > 65535
  then
    notify(
      ('invalid port: %s'):format(input),
      levels.WARN
    )

    return default
  end

  return math.floor(value)
end

---@return integer
local function node_attach_port()
  return prompt_port(
    'Node inspector port: ',
    DEFAULT_NODE_PORT
  )
end

---@return integer
local function browser_attach_port()
  return prompt_port(
    'Browser debugging port: ',
    DEFAULT_BROWSER_PORT
  )
end

---@return string
local function prompt_npm_script()
  local value = fn.input(
    'npm script: ',
    'dev'
  )

  if value == '' then
    return 'dev'
  end

  return value
end

---@return string[]
local function npm_runtime_args()
  return {
    'run',
    prompt_npm_script(),
  }
end

---@param root string
---@param executable string
---@return string?
local function local_node_bin(
  root,
  executable
)
  local candidate = fs.joinpath(
    root,
    'node_modules',
    '.bin',
    executable
  )

  if readable_file(candidate) then
    return fs.normalize(candidate)
  end

  return nil
end

---@return string?
local function resolve_ts_runtime()
  local root = project_root()

  return local_node_bin(root, 'tsx')
    or executable_path('tsx')
    or local_node_bin(root, 'ts-node')
    or executable_path('ts-node')
end

---@return string
local function typescript_runtime()
  local runtime = resolve_ts_runtime()

  if runtime ~= nil then
    return runtime
  end

  notify(
    'tsx or ts-node was not found; direct TypeScript launch may fail',
    levels.WARN
  )

  return node()
end

---@return string[]
local function out_files()
  local root = cwd()

  return {
    fs.joinpath(root, 'dist', '**', '*.js'),
    fs.joinpath(root, 'build', '**', '*.js'),
    fs.joinpath(root, 'out', '**', '*.js'),
    fs.joinpath(root, '.next', '**', '*.js'),
    '!' .. fs.joinpath(
      root,
      'node_modules',
      '**'
    ),
  }
end

---@return string[]
local function source_map_locations()
  local root = cwd()

  return {
    fs.joinpath(root, '**'),
    '!' .. fs.joinpath(
      root,
      'node_modules',
      '**'
    ),
  }
end

---@return boolean
local function current_is_typescript()
  return TYPESCRIPT_FILETYPES[
    filetype()
  ] == true
end

---@return string
local function current_runtime()
  if current_is_typescript() then
    return typescript_runtime()
  end

  return node()
end

---@return string
local function browser_executable()
  local configured =
    vim.env.NVIM_JS_DEBUG_BROWSER

  if nonempty_string(configured) then
    local expanded = fn.expand(configured)

    if fn.executable(expanded) == 1 then
      return fs.normalize(expanded)
    end
  end

  local candidates = {
    'chromium',
    'chromium-browser',
    'google-chrome-stable',
    'google-chrome',
  }

  for _, command in ipairs(candidates) do
    local executable = executable_path(
      command
    )

    if executable ~= nil then
      return executable
    end
  end

  return 'chromium'
end

local function show_status()
  local adapter = resolve_adapter()
  local node_path = executable_path('node')
  local ts_runtime = resolve_ts_runtime()

  notify(
    table.concat({
      'root: ' .. project_root(),

      'node: '
        .. (node_path or 'not found'),

      'TypeScript runtime: '
        .. (ts_runtime or 'not found'),

      'adapter: '
        .. (adapter or 'not found'),

      'browser: '
        .. browser_executable(),
    }, '\n'),
    (
      adapter ~= nil
      and node_path ~= nil
    )
        and levels.INFO
      or levels.WARN
  )
end

local function select_adapter()
  local selected = fn.input(
    'js-debug adapter: ',
    resolve_adapter() or '',
    'file'
  )

  if selected == '' then
    return
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not readable_file(selected) then
    notify(
      (
        'not a readable js-debug adapter: %s'
      ):format(selected),
      levels.ERROR
    )

    return
  end

  state.adapter = selected

  local function update_adapter(adapter)
    if
      type(adapter) ~= 'table'
      or type(adapter.executable) ~= 'table'
    then
      return
    end

    adapter.executable.args = {
      selected,
      '${port}',
    }
  end

  update_adapter(
    M.adapters['pwa-node']
  )

  update_adapter(
    M.adapters['pwa-chrome']
  )

  notify(
    ('js-debug adapter: %s'):format(
      selected
    )
  )
end

local function clear_adapter()
  state.adapter = nil

  notify(
    'js-debug adapter path cache cleared'
  )
end

--
-- vscode-js-debug's standalone dapDebugServer.js listens on a TCP port.
--
-- The same server implements both pwa-node and pwa-chrome. The configuration
-- `type` determines which target implementation is selected.
--
---@type table<string, table>
M.adapters = {
  ['pwa-node'] = {
    name = 'pwa-node',

    type = 'server',

    host = '127.0.0.1',

    port = '${port}',

    executable = {
      command = node(),

      args = {
        required_adapter(),
        '${port}',
      },
    },
  },

  ['pwa-chrome'] = {
    name = 'pwa-chrome',

    type = 'server',

    host = '127.0.0.1',

    port = '${port}',

    executable = {
      command = node(),

      args = {
        required_adapter(),
        '${port}',
      },
    },
  },
}

---@type table[]
local configurations = {
  --
  -- JavaScript / automatically selected runtime.
  --
  {
    name = 'JS/TS: Current File',

    type = 'pwa-node',

    request = 'launch',

    program = current_file,

    cwd = cwd,

    runtimeExecutable = current_runtime,

    args = {},

    console = 'integratedTerminal',

    sourceMaps = true,

    smartStep = true,

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },

    resolveSourceMapLocations =
      source_map_locations,

    autoAttachChildProcesses = true,
  },

  {
    name = 'JS/TS: Current File with Arguments',

    type = 'pwa-node',

    request = 'launch',

    program = current_file,

    cwd = cwd,

    runtimeExecutable = current_runtime,

    args = prompt_args,

    console = 'integratedTerminal',

    sourceMaps = true,

    smartStep = true,

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },

    resolveSourceMapLocations =
      source_map_locations,

    autoAttachChildProcesses = true,
  },

  --
  -- Explicit compiled TypeScript mode.
  --
  -- Use this when tsc/Vite/Webpack/etc. generate JavaScript separately.
  --
  {
    name = 'TypeScript: Compiled Project',

    type = 'pwa-node',

    request = 'launch',

    program = current_file,

    cwd = cwd,

    runtimeExecutable = node,

    sourceMaps = true,

    smartStep = true,

    outFiles = out_files,

    resolveSourceMapLocations =
      source_map_locations,

    console = 'integratedTerminal',

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },

    autoAttachChildProcesses = true,
  },

  --
  -- Direct TypeScript execution through tsx/ts-node.
  --
  {
    name = 'TypeScript: Current File via tsx',

    type = 'pwa-node',

    request = 'launch',

    program = current_file,

    cwd = cwd,

    runtimeExecutable = typescript_runtime,

    sourceMaps = true,

    smartStep = true,

    console = 'integratedTerminal',

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },

    autoAttachChildProcesses = true,
  },

  --
  -- npm/project-script debugging is particularly useful for Ember/Glimmer,
  -- Vite, Next.js, Remix, React and similar toolchains.
  --
  {
    name = 'Node: npm Script',

    type = 'pwa-node',

    request = 'launch',

    cwd = cwd,

    runtimeExecutable = 'npm',

    runtimeArgs = npm_runtime_args,

    console = 'integratedTerminal',

    sourceMaps = true,

    smartStep = true,

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },

    autoAttachChildProcesses = true,
  },

  --
  -- Attach to:
  --
  --   node --inspect=127.0.0.1:9229 app.js
  --
  -- or:
  --
  --   node --inspect-brk=127.0.0.1:9229 app.js
  --
  {
    name = 'Node: Attach localhost:9229',

    type = 'pwa-node',

    request = 'attach',

    address = '127.0.0.1',

    port = DEFAULT_NODE_PORT,

    cwd = cwd,

    sourceMaps = true,

    smartStep = true,

    restart = false,

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },
  },

  {
    name = 'Node: Attach (Choose Port)',

    type = 'pwa-node',

    request = 'attach',

    address = '127.0.0.1',

    port = node_attach_port,

    cwd = cwd,

    sourceMaps = true,

    smartStep = true,

    skipFiles = {
      '<node_internals>/**',
      '**/node_modules/**',
    },
  },

  --
  -- Launch a dedicated Chromium instance.
  --
  {
    name = 'Browser: Launch Chromium',

    type = 'pwa-chrome',

    request = 'launch',

    url = prompt_url,

    webRoot = cwd,

    cwd = cwd,

    runtimeExecutable =
      browser_executable,

    sourceMaps = true,

    smartStep = true,

    userDataDir = true,

    resolveSourceMapLocations =
      source_map_locations,

    skipFiles = {
      '**/node_modules/**',
    },
  },

  --
  -- Attach to a Chromium instance started with:
  --
  --   chromium --remote-debugging-port=9222
  --
  {
    name = 'Browser: Attach localhost:9222',

    type = 'pwa-chrome',

    request = 'attach',

    address = '127.0.0.1',

    port = DEFAULT_BROWSER_PORT,

    webRoot = cwd,

    sourceMaps = true,

    smartStep = true,

    resolveSourceMapLocations =
      source_map_locations,

    skipFiles = {
      '**/node_modules/**',
    },
  },

  {
    name = 'Browser: Attach (Choose Port)',

    type = 'pwa-chrome',

    request = 'attach',

    address = '127.0.0.1',

    port = browser_attach_port,

    webRoot = cwd,

    sourceMaps = true,

    smartStep = true,

    resolveSourceMapLocations =
      source_map_locations,

    skipFiles = {
      '**/node_modules/**',
    },
  },
}

--
-- One adapter/configuration stack is intentionally shared across JavaScript,
-- TypeScript, JSX, TSX and Glimmer. vscode-js-debug performs JavaScript
-- debugging while its source-map engine maps generated JavaScript back to
-- TypeScript/Glimmer sources.
--
---@type table<string, table[]>
M.configurations = {
  javascript = configurations,

  javascriptreact = configurations,

  typescript = configurations,

  typescriptreact = configurations,

  ['javascript.glimmer'] = configurations,

  ['typescript.glimmer'] = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  JsDebugAdapter = {
    callback = function()
      select_adapter()
    end,

    desc = 'Select vscode-js-debug adapter',
  },

  JsDebugAdapterClear = {
    callback = function()
      clear_adapter()
    end,

    desc = 'Clear vscode-js-debug adapter cache',
  },

  JsDebugStatus = {
    callback = function()
      show_status()
    end,

    desc = 'Show JavaScript debugger status',
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  js_debug_adapter = {
    lhs = '<leader>dJa',

    mode = 'n',

    rhs = function()
      select_adapter()
    end,

    desc = 'Debug JS: Select adapter',
  },

  js_debug_status = {
    lhs = '<leader>dJs',

    mode = 'n',

    rhs = function()
      show_status()
    end,

    desc = 'Debug JS: Status',
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  local node_path =
    executable_path('node')

  if node_path == nil then
    vim.schedule(function()
      notify(
        'Node.js is required by vscode-js-debug',
        levels.ERROR
      )
    end)

    return
  end

  local adapter = resolve_adapter()

  if adapter == nil then
    vim.schedule(function()
      notify(
        table.concat({
          'vscode-js-debug standalone DAP server was not found.',
          '',
          'Set either:',
          '  NVIM_JS_DEBUG_ADAPTER=/path/to/dapDebugServer.js',
          '  NVIM_JS_DEBUG_ROOT=/path/to/vscode-js-debug',
        }, '\n'),
        levels.WARN
      )
    end)

    return
  end

  local function configure_adapter(spec)
    if
      type(spec) ~= 'table'
      or type(spec.executable) ~= 'table'
    then
      return
    end

    spec.executable.command =
      node_path

    spec.executable.args = {
      adapter,
      '${port}',
    }
  end

  configure_adapter(
    M.adapters['pwa-node']
  )

  configure_adapter(
    M.adapters['pwa-chrome']
  )
end

---@return string?
function M.adapter()
  return resolve_adapter()
end

---@return string
function M.root()
  return project_root()
end

return M