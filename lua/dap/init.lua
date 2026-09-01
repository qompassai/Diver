-- #################################################################
-- ~/.config/nvim/lua/dap/init.lua
-- Qompass AI Diver Native Debug Adapter Configuration
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

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local MODULE_PREFIX = "dap."
local NOTIFY_PREFIX = "[debug] "

local augroup = api.nvim_create_augroup(
  "NativeDebug",
  {
    clear = true,
  }
)

---@class DebugCommand
---@field callback fun(args: vim.api.keyset.create_user_command.command_args)
---@field bang? boolean
---@field complete? string|fun(...): string[]
---@field desc? string
---@field nargs? integer|string

---@class DebugMapping
---@field desc? string
---@field lhs string
---@field mode? string|string[]
---@field rhs string|function

---@class DebugModule
---@field adapter? table
---@field adapters? table<string, table>
---@field commands? table<string, DebugCommand>
---@field configurations? table<string, table[]>
---@field filetypes? string[]
---@field mappings? table<string, DebugMapping>
---@field setup? fun(opts?: table)
---@field teardown? fun()

---@class DebugModuleSpec
---@field filetypes string[]
---@field module string
---@field condition? fun(bufnr: integer, root: string): boolean
---@field root? fun(bufnr: integer): string?

---@class DebugRegistry
---@field adapters table<string, table>
---@field configurations table<string, table[]>

---@class DebugActivation
---@field bufnr integer
---@field root string

---@type DebugRegistry
local registry = {
  adapters = {},
  configurations = {},
}

---@type table<string, DebugModule>
local modules = {}

---@type table<string, boolean>
local failed_modules = {}

---@type table<string, boolean>
local registered_commands = {}

---@type table<string, boolean>
local registered_mappings = {}

---@type table<string, table<string, boolean>>
local registered_configurations = {}

---@type table<string, table<string, boolean>>
local module_activations = {}

---@type table<string, boolean>
local module_definitions_registered = {}

local setup_complete = false

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(
    NOTIFY_PREFIX .. message,
    level or levels.INFO
  )
end

---@param value unknown
---@return boolean
local function callable(value)
  return type(value) == "function"
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == "string"
    and value ~= ""
end

---@param path string
---@return string
local function normalize(path)
  if path == "" then
    return ""
  end

  return fs.normalize(
    fn.fnamemodify(
      path,
      ":p"
    )
  )
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
local function is_directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "directory"
end

---@param bufnr? integer
---@return string
function M.filename(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  local name = api.nvim_buf_get_name(bufnr)

  if name == "" then
    return ""
  end

  return normalize(name)
end

---@param bufnr? integer
---@return string
function M.filetype(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  return vim.bo[bufnr].filetype
end

---@param bufnr? integer
---@return string
function M.root(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local filename = M.filename(bufnr)

  if filename == "" then
    return normalize(
      fn.getcwd()
    )
  end

  local detected = fs.root(
    filename,
    {
      ".git",
      ".hg",
      ".svn",
    }
  )

  if
    type(detected) == "string"
    and detected ~= ""
  then
    return fs.normalize(detected)
  end

  return fs.dirname(filename)
    or normalize(
      fn.getcwd()
    )
end

---@param command string
---@return boolean
function M.executable(command)
  assert(
    nonempty_string(command),
    "command must be a non-empty string"
  )

  return fn.executable(command) == 1
end

---@param path string
---@return boolean
function M.exists(path)
  assert(
    nonempty_string(path),
    "path must be a non-empty string"
  )

  return exists(path)
end

---@param path string
---@return string
function M.normalize(path)
  assert(
    type(path) == "string",
    "path must be a string"
  )

  return normalize(path)
end

--
-- Native backend
--

---@return table?
local function native_backend()
  local candidate = rawget(
    vim,
    "debug"
  )

  if type(candidate) ~= "table" then
    return nil
  end

  return candidate
end

---@return boolean
function M.backend_available()
  return native_backend() ~= nil
end

---@return table?
function M.backend()
  return native_backend()
end

---@return DebugRegistry
function M.registry()
  return registry
end

---@param table_value table
---@param key string
---@return function?
local function method(
  table_value,
  key
)
  local value = table_value[key]

  if not callable(value) then
    return nil
  end

  return value
end

---@param name string
---@param callback unknown
---@param ... unknown
---@return boolean, unknown?
local function protected_call(
  name,
  callback,
  ...
)
  if not callable(callback) then
    return false, nil
  end

  local ok, result = pcall(
    callback,
    ...
  )

  if not ok then
    notify(
      ("%s failed: %s"):format(
        name,
        tostring(result)
      ),
      levels.ERROR
    )

    return false, nil
  end

  return true, result
end

---@param names string[]
---@param ... unknown
---@return boolean, unknown?
local function backend_call_any(
  names,
  ...
)
  local backend = native_backend()

  if backend == nil then
    notify(
      "native DAP backend is unavailable",
      levels.WARN
    )

    return false, nil
  end

  for _, name in ipairs(names) do
    local callback = method(
      backend,
      name
    )

    if callback ~= nil then
      return protected_call(
        name,
        callback,
        ...
      )
    end
  end

  notify(
    (
      "native debug backend does not provide %s"
    ):format(
      table.concat(
        names,
        " or "
      )
    ),
    levels.WARN
  )

  return false, nil
end

---@param name string
---@param ... unknown
---@return boolean, unknown?
local function backend_call(
  name,
  ...
)
  return backend_call_any(
    {
      name,
    },
    ...
  )
end

--
-- Project detection
--

---@param bufnr integer
---@return string
local function buffer_directory(bufnr)
  local filename = M.filename(bufnr)

  if filename == "" then
    return ""
  end

  return fs.dirname(filename)
    or ""
end

---@param start string
---@param marker string
---@return string?
local function find_upward_marker(
  start,
  marker
)
  local directory = start

  while nonempty_string(directory) do
    if exists(
      fs.joinpath(
        directory,
        marker
      )
    ) then
      return fs.normalize(directory)
    end

    local parent = fs.dirname(directory)

    if
      parent == nil
      or parent == directory
    then
      break
    end

    directory = parent
  end

  return nil
end

---@param directory string
---@param suffix string
---@return boolean
local function directory_has_suffix(
  directory,
  suffix
)
  if not is_directory(directory) then
    return false
  end

  local ok, iterator = pcall(
    fs.dir,
    directory
  )

  if not ok then
    return false
  end

  for name, kind in iterator do
    if
      kind == "file"
      and #name >= #suffix
      and name:sub(-#suffix) == suffix
    then
      return true
    end
  end

  return false
end

---@param start string
---@param suffix string
---@return string?
local function find_upward_suffix(
  start,
  suffix
)
  local directory = start

  while nonempty_string(directory) do
    if directory_has_suffix(
      directory,
      suffix
    ) then
      return fs.normalize(directory)
    end

    local parent = fs.dirname(directory)

    if
      parent == nil
      or parent == directory
    then
      break
    end

    directory = parent
  end

  return nil
end

---@param bufnr integer
---@return string?
local function android_root(bufnr)
  local directory = buffer_directory(bufnr)

  if directory == "" then
    return nil
  end

  local manifest_root = find_upward_marker(
    directory,
    "AndroidManifest.xml"
  )

  if manifest_root ~= nil then
    return manifest_root
  end

  local root = fs.root(
    directory,
    {
      "settings.gradle",
      "settings.gradle.kts",
      "build.gradle",
      "build.gradle.kts",
      "gradlew",
      ".git",
    }
  )

  if
    type(root) ~= "string"
    or root == ""
  then
    return nil
  end

  local manifests = {
    fs.joinpath(
      root,
      "AndroidManifest.xml"
    ),

    fs.joinpath(
      root,
      "src",
      "main",
      "AndroidManifest.xml"
    ),

    fs.joinpath(
      root,
      "app",
      "src",
      "main",
      "AndroidManifest.xml"
    ),
  }

  for _, manifest in ipairs(manifests) do
    if exists(manifest) then
      return fs.normalize(root)
    end
  end

  return nil
end

---@param bufnr integer
---@return boolean
local function is_android_project(bufnr)
  return android_root(bufnr) ~= nil
end

---@param bufnr integer
---@return string?
local function unreal_root(bufnr)
  local directory = buffer_directory(bufnr)

  if directory == "" then
    return nil
  end

  return find_upward_suffix(
    directory,
    ".uproject"
  )
end

---@param bufnr integer
---@return boolean
local function is_unreal_project(bufnr)
  return unreal_root(bufnr) ~= nil
end

---@param bufnr integer
---@return string?
local function sqlite_root(bufnr)
  if
    nonempty_string(
      vim.env.NVIM_SQLITE_DATABASE
    )
  then
    return M.root(bufnr)
  end

  local configured =
    vim.env.NVIM_SQL_BACKEND

  if
    nonempty_string(configured)
    and configured:lower() == "sqlite"
  then
    return M.root(bufnr)
  end

  local directory = buffer_directory(bufnr)

  if directory == "" then
    return nil
  end

  local root = fs.root(
    directory,
    {
      ".git",
    }
  )

  root = root
    or directory

  local extensions = {
    ".db",
    ".db3",
    ".sqlite",
    ".sqlite3",
  }

  local ok, iterator = pcall(
    fs.dir,
    root
  )

  if not ok then
    return nil
  end

  for name, kind in iterator do
    if kind == "file" then
      local lower = name:lower()

      for _, extension in ipairs(
        extensions
      ) do
        if
          #lower >= #extension
          and lower:sub(-#extension)
            == extension
        then
          return fs.normalize(root)
        end
      end
    end
  end

  return nil
end

---@param bufnr integer
---@return boolean
local function is_sqlite_project(bufnr)
  return sqlite_root(bufnr) ~= nil
end

--
-- Module catalog
--

---@type DebugModuleSpec[]
local MODULES = {
  {
    filetypes = {
      "java",
      "kotlin",
      "rust",
    },

    module = "android",

    condition = function(bufnr)
      return is_android_project(bufnr)
    end,

    root = android_root,
  },

  {
    filetypes = {
      "apex",
    },

    module = "apex",
  },

  {
    filetypes = {
      "bash",
      "sh",
    },

    module = "bash",
  },

  {
    filetypes = {
      "cs",
      "razor",
    },

    module = "csharp",
  },

  {
    filetypes = {
      "go",
    },

    module = "go",
  },

  {
    filetypes = {
      "java",
    },

    module = "java",
  },

  {
    filetypes = {
      "kotlin",
    },

    module = "kotlin",
  },

  {
    filetypes = {
      "lua",
    },

    module = "lua",
  },

  {
    filetypes = {
      "mojo",
    },

    module = "mojo",
  },

  {
    filetypes = {
      "nix",
    },

    module = "nix",
  },

  {
    filetypes = {
      "javascript",
      "javascriptreact",
      "javascript.glimmer",
      "typescript",
      "typescriptreact",
      "typescript.glimmer",
      "glimmer",
    },

    module = "node",
  },

  {
    filetypes = {
      "pgsql",
      "postgresql",
    },

    module = "postgres",
  },

  {
    filetypes = {
      "ps1",
      "powershell",
    },

    module = "powershell",
  },

  {
    filetypes = {
      "python",
    },

    module = "python",
  },

  {
    filetypes = {
      "rust",
    },

    module = "rust",
  },

  {
    filetypes = {
      "scala",
    },

    module = "scala",
  },

  {
    filetypes = {
      "sql",
    },

    module = "sql",
  },

  {
    filetypes = {
      "sql",
    },

    module = "sqlite",

    condition = function(bufnr)
      return is_sqlite_project(bufnr)
    end,

    root = sqlite_root,
  },

  {
    filetypes = {
      "sqlite",
    },

    module = "sqlite",
  },

  {
    filetypes = {
      "c",
      "cpp",
    },

    module = "unreal",

    condition = function(bufnr)
      return is_unreal_project(bufnr)
    end,

    root = unreal_root,
  },
}

---@param spec DebugModuleSpec
---@param filetype string
---@return boolean
local function spec_matches_filetype(
  spec,
  filetype
)
  for _, candidate in ipairs(
    spec.filetypes
  ) do
    if candidate == filetype then
      return true
    end
  end

  return false
end

---@param spec DebugModuleSpec
---@param bufnr integer
---@param root string
---@return boolean
local function spec_enabled(
  spec,
  bufnr,
  root
)
  if spec.condition == nil then
    return true
  end

  local ok, result = pcall(
    spec.condition,
    bufnr,
    root
  )

  if not ok then
    notify(
      (
        "module condition failed for %s: %s"
      ):format(
        spec.module,
        tostring(result)
      ),
      levels.WARN
    )

    return false
  end

  return result == true
end

---@param spec DebugModuleSpec
---@param bufnr integer
---@return string
local function spec_root(
  spec,
  bufnr
)
  if spec.root ~= nil then
    local ok, result = pcall(
      spec.root,
      bufnr
    )

    if
      ok
      and nonempty_string(result)
    then
      return fs.normalize(result)
    end
  end

  return M.root(bufnr)
end

---@return string[]
local function module_names()
  local seen = {}

  ---@type string[]
  local result = {}

  for _, spec in ipairs(MODULES) do
    if not seen[spec.module] then
      seen[spec.module] = true

      result[#result + 1] =
        spec.module
    end
  end

  table.sort(result)

  return result
end

--
-- Adapter registration
--

---@param name string
---@param adapter table
---@return boolean
local function register_adapter(
  name,
  adapter
)
  assert(
    nonempty_string(name),
    "adapter name must be non-empty"
  )

  assert(
    type(adapter) == "table",
    "adapter must be a table"
  )

  registry.adapters[name] =
    adapter

  local backend = native_backend()

  if backend == nil then
    return false
  end

  if
    type(backend.adapters) == "table"
  then
    backend.adapters[name] =
      adapter

    return true
  end

  local callback = method(
    backend,
    "register_adapter"
  )

  if callback == nil then
    return false
  end

  local ok = protected_call(
    "register_adapter",
    callback,
    name,
    adapter
  )

  return ok
end

---@param configuration table
---@return string
local function configuration_key(
  configuration
)
  return table.concat({
    tostring(
      configuration.name or ""
    ),

    tostring(
      configuration.type or ""
    ),

    tostring(
      configuration.request or ""
    ),
  }, "\0")
end

---@param destination table[]
---@param source table[]
local function merge_configurations(
  destination,
  source
)
  local seen = {}

  for _, configuration in ipairs(
    destination
  ) do
    seen[
      configuration_key(
        configuration
      )
    ] = true
  end

  for _, configuration in ipairs(
    source
  ) do
    local key =
      configuration_key(
        configuration
      )

    if not seen[key] then
      seen[key] = true

      destination[#destination + 1] =
        configuration
    end
  end
end

---@param filetype string
---@param configurations table[]
---@return boolean
local function register_configurations(
  filetype,
  configurations
)
  assert(
    nonempty_string(filetype),
    "filetype must be non-empty"
  )

  assert(
    type(configurations) == "table",
    "configurations must be a table"
  )

  local merged =
    registry.configurations[filetype]

  if merged == nil then
    merged = {}

    registry.configurations[filetype] =
      merged
  end

  merge_configurations(
    merged,
    configurations
  )

  local backend = native_backend()

  if backend == nil then
    return false
  end

  --
  -- Preferred backend shape:
  --
  -- direct mutable configuration registry.
  --
  if
    type(backend.configurations) == "table"
  then
    backend.configurations[filetype] =
      merged

    return true
  end

  local callback = method(
    backend,
    "register_configuration"
  )

  if callback == nil then
    return false
  end

  local registered =
    registered_configurations[filetype]

  if registered == nil then
    registered = {}

    registered_configurations[filetype] =
      registered
  end

  local success = true

  for _, configuration in ipairs(
    configurations
  ) do
    local key =
      configuration_key(
        configuration
      )

    if not registered[key] then
      local ok = protected_call(
        "register_configuration",
        callback,
        filetype,
        configuration
      )

      if ok then
        registered[key] = true
      else
        success = false
      end
    end
  end

  return success
end

--
-- Commands
--

---@param name string
---@param spec DebugCommand
local function register_command(
  name,
  spec
)
  if registered_commands[name] then
    return
  end

  if
    not nonempty_string(name)
    or type(spec) ~= "table"
    or not callable(spec.callback)
  then
    return
  end

  local existing =
    api.nvim_get_commands({
      builtin = false,
    })

  if existing[name] ~= nil then
    registered_commands[name] =
      true

    return
  end

  api.nvim_create_user_command(
    name,
    spec.callback,
    {
      bang =
        spec.bang == true,

      complete =
        spec.complete,

      desc =
        spec.desc,

      nargs =
        spec.nargs or 0,
    }
  )

  registered_commands[name] =
    true
end

---@param commands table<string, DebugCommand>
local function register_commands(commands)
  for name, spec in pairs(commands) do
    register_command(
      name,
      spec
    )
  end
end

--
-- Mappings
--

---@param mode string|string[]|nil
---@param lhs string
---@return string
local function mapping_key(
  mode,
  lhs
)
  if type(mode) == "table" then
    local modes =
      vim.deepcopy(mode)

    table.sort(modes)

    return table.concat(
      modes,
      ","
    ) .. "\0" .. lhs
  end

  return tostring(
    mode or "n"
  ) .. "\0" .. lhs
end

---@param name string
---@param spec DebugMapping
local function register_mapping(
  name,
  spec
)
  if type(spec) ~= "table" then
    return
  end

  if not nonempty_string(spec.lhs) then
    return
  end

  local rhs = spec.rhs

  if
    type(rhs) ~= "string"
    and not callable(rhs)
  then
    return
  end

  local key = mapping_key(
    spec.mode,
    spec.lhs
  )

  if registered_mappings[key] then
    return
  end

  vim.keymap.set(
    spec.mode or "n",
    spec.lhs,
    rhs,
    {
      desc =
        spec.desc,

      silent = true,
    }
  )

  registered_mappings[key] =
    true

  registered_mappings[name] =
    true
end

---@param mappings table<string, DebugMapping>
local function register_mappings(mappings)
  for name, spec in pairs(mappings) do
    register_mapping(
      name,
      spec
    )
  end
end

--
-- Module loading and activation
--

---@param module_name string
---@return DebugModule?
local function require_module(
  module_name
)
  if modules[module_name] ~= nil then
    return modules[module_name]
  end

  if failed_modules[module_name] then
    return nil
  end

  local ok, module = pcall(
    require,
    MODULE_PREFIX .. module_name
  )

  if not ok then
    failed_modules[module_name] =
      true

    notify(
      (
        "failed to load %s: %s"
      ):format(
        module_name,
        tostring(module)
      ),
      levels.WARN
    )

    return nil
  end

  if type(module) ~= "table" then
    failed_modules[module_name] =
      true

    notify(
      (
        "%s must return a table"
      ):format(
        module_name
      ),
      levels.ERROR
    )

    return nil
  end

  modules[module_name] =
    module

  return module
end

---@param module_name string
---@param module DebugModule
local function register_module_definition(
  module_name,
  module
)
  if module_definitions_registered[module_name] then
    return
  end

  if type(module.adapters) == "table" then
    for name, adapter in pairs(
      module.adapters
    ) do
      if
        nonempty_string(name)
        and type(adapter) == "table"
      then
        register_adapter(
          name,
          adapter
        )
      end
    end
  end

  if type(module.adapter) == "table" then
    local name =
      module.adapter.name

    if nonempty_string(name) then
      register_adapter(
        name,
        module.adapter
      )
    end
  end

  if
    type(module.configurations) == "table"
  then
    for filetype, configurations in pairs(
      module.configurations
    ) do
      if
        nonempty_string(filetype)
        and type(configurations) == "table"
      then
        register_configurations(
          filetype,
          configurations
        )
      end
    end
  end

  if type(module.commands) == "table" then
    register_commands(
      module.commands
    )
  end

  if type(module.mappings) == "table" then
    register_mappings(
      module.mappings
    )
  end

  module_definitions_registered[module_name] =
    true
end

---@param module_name string
---@param module DebugModule
---@param bufnr integer
---@param root string
local function activate_module(
  module_name,
  module,
  bufnr,
  root
)
  if not callable(module.setup) then
    return
  end

  local activations =
    module_activations[module_name]

  if activations == nil then
    activations = {}

    module_activations[module_name] =
      activations
  end

  local activation_key =
    fs.normalize(root)

  if activations[activation_key] then
    return
  end

  local backend =
    native_backend()

  local ok, setup_error =
    pcall(
      module.setup,
      {
        backend = backend,

        bufnr = bufnr,

        debug = backend,

        root = root,
      }
    )

  if not ok then
    notify(
      (
        "%s setup failed for %s: %s"
      ):format(
        module_name,
        root,
        tostring(setup_error)
      ),
      levels.ERROR
    )

    return
  end

  activations[activation_key] =
    true
end

---@param module_name string
---@param bufnr? integer
---@param root? string
---@return boolean
function M.load(
  module_name,
  bufnr,
  root
)
  assert(
    nonempty_string(module_name),
    "module_name must be non-empty"
  )

  bufnr = bufnr
    or api.nvim_get_current_buf()

  root = root
    or M.root(bufnr)

  local module =
    require_module(module_name)

  if module == nil then
    return false
  end

  register_module_definition(
    module_name,
    module
  )

  activate_module(
    module_name,
    module,
    bufnr,
    fs.normalize(root)
  )

  return true
end

---@param filetype string
---@param bufnr? integer
function M.load_filetype(
  filetype,
  bufnr
)
  if filetype == "" then
    return
  end

  bufnr = bufnr
    or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, spec in ipairs(MODULES) do
    if spec_matches_filetype(
      spec,
      filetype
    ) then
      local root =
        spec_root(
          spec,
          bufnr
        )

      if spec_enabled(
        spec,
        bufnr,
        root
      ) then
        M.load(
          spec.module,
          bufnr,
          root
        )
      end
    end
  end
end

---@return string[]
function M.loaded()
  local result = {}

  for module_name in pairs(modules) do
    result[#result + 1] =
      module_name
  end

  table.sort(result)

  return result
end

---@return string[]
function M.failed()
  local result = {}

  for module_name, failed in pairs(
    failed_modules
  ) do
    if failed then
      result[#result + 1] =
        module_name
    end
  end

  table.sort(result)

  return result
end

---@param module_name string
---@return string[]
function M.activations(module_name)
  local roots =
    module_activations[module_name]

  if roots == nil then
    return {}
  end

  local result = {}

  for root, active in pairs(roots) do
    if active then
      result[#result + 1] =
        root
    end
  end

  table.sort(result)

  return result
end

--
-- Session controls
--

function M.continue()
  backend_call_any({
    "continue",
    "run",
    "start",
  })
end

function M.disconnect()
  backend_call_any({
    "disconnect",
    "stop",
    "terminate",
  })
end

function M.pause()
  backend_call(
    "pause"
  )
end

function M.restart()
  local backend =
    native_backend()

  if backend == nil then
    notify(
      "native DAP backend is unavailable",
      levels.WARN
    )

    return
  end

  local callback = method(
    backend,
    "restart"
  )

  if callback ~= nil then
    protected_call(
      "restart",
      callback
    )

    return
  end

  local stop_callback =
    method(
      backend,
      "stop"
    )
      or method(
        backend,
        "terminate"
      )

  local run_callback =
    method(
      backend,
      "run_last"
    )
      or method(
        backend,
        "run"
      )
      or method(
        backend,
        "start"
      )

  if
    stop_callback == nil
    or run_callback == nil
  then
    notify(
      "native debug backend cannot restart sessions",
      levels.WARN
    )

    return
  end

  local ok = protected_call(
    "stop",
    stop_callback
  )

  if not ok then
    return
  end

  vim.schedule(function()
    protected_call(
      "run",
      run_callback
    )
  end)
end

function M.run()
  local bufnr =
    api.nvim_get_current_buf()

  local filetype =
    M.filetype(bufnr)

  M.load_filetype(
    filetype,
    bufnr
  )

  backend_call_any({
    "run",
    "start",
    "continue",
  })
end

function M.run_last()
  backend_call_any({
    "run_last",
    "run",
    "start",
  })
end

function M.step_back()
  backend_call_any({
    "step_back",
    "stepBack",
  })
end

function M.step_into()
  backend_call_any({
    "step_into",
    "stepInto",
  })
end

function M.step_out()
  backend_call_any({
    "step_out",
    "stepOut",
  })
end

function M.step_over()
  backend_call_any({
    "step_over",
    "stepOver",
    "next",
  })
end

function M.stop()
  backend_call_any({
    "stop",
    "terminate",
    "disconnect",
  })
end

function M.terminate()
  backend_call_any({
    "terminate",
    "stop",
    "disconnect",
  })
end

--
-- Breakpoints
--

function M.toggle_breakpoint()
  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "toggle_breakpoint"
      )
        or method(
          backend,
          "toggleBreakpoint"
        )

    if callback ~= nil then
      protected_call(
        "toggle_breakpoint",
        callback
      )

      return
    end
  end

  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    ok
    and type(breakpoints) == "table"
    and callable(breakpoints.toggle)
  then
    local success, breakpoint_error =
      pcall(
        breakpoints.toggle
      )

    if not success then
      notify(
        (
          "breakpoint toggle failed: %s"
        ):format(
          tostring(
            breakpoint_error
          )
        ),
        levels.ERROR
      )
    end

    return
  end

  notify(
    "no breakpoint backend is available",
    levels.WARN
  )
end

function M.clear_breakpoints()
  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "clear_breakpoints"
      )
        or method(
          backend,
          "clearBreakpoints"
        )

    if callback ~= nil then
      protected_call(
        "clear_breakpoints",
        callback
      )

      return
    end
  end

  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    ok
    and type(breakpoints) == "table"
    and callable(breakpoints.clear)
  then
    pcall(
      breakpoints.clear
    )

    return
  end

  notify(
    "no breakpoint backend is available",
    levels.WARN
  )
end

function M.set_conditional_breakpoint()
  local condition = fn.input(
    "Breakpoint condition: "
  )

  if condition == "" then
    return
  end

  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "set_breakpoint"
      )
        or method(
          backend,
          "setBreakpoint"
        )

    if callback ~= nil then
      protected_call(
        "set_breakpoint",
        callback,
        {
          condition = condition,
        }
      )

      return
    end
  end

  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    ok
    and type(breakpoints) == "table"
    and callable(breakpoints.set)
  then
    pcall(
      breakpoints.set,
      {
        condition = condition,
      }
    )

    return
  end

  notify(
    "no breakpoint backend is available",
    levels.WARN
  )
end

function M.set_logpoint()
  local message = fn.input(
    "Log point message: "
  )

  if message == "" then
    return
  end

  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "set_breakpoint"
      )
        or method(
          backend,
          "setBreakpoint"
        )

    if callback ~= nil then
      protected_call(
        "set_breakpoint",
        callback,
        {
          log_message = message,
          logMessage = message,
        }
      )

      return
    end
  end

  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    ok
    and type(breakpoints) == "table"
    and callable(breakpoints.set)
  then
    pcall(
      breakpoints.set,
      {
        log_message = message,
        logMessage = message,
      }
    )

    return
  end

  notify(
    "no breakpoint backend is available",
    levels.WARN
  )
end

--
-- Views / inspection
--

function M.repl()
  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "repl"
      )

    if callback ~= nil then
      protected_call(
        "repl",
        callback
      )

      return
    end
  end

  local ok, widgets = pcall(
    require,
    "dap.widgets"
  )

  if
    ok
    and type(widgets) == "table"
    and callable(widgets.repl)
  then
    pcall(
      widgets.repl
    )

    return
  end

  notify(
    "no debug REPL backend is available",
    levels.WARN
  )
end

function M.hover()
  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "hover"
      )

    if callback ~= nil then
      protected_call(
        "hover",
        callback
      )

      return
    end
  end

  local ok, widgets = pcall(
    require,
    "dap.widgets"
  )

  if
    ok
    and type(widgets) == "table"
    and callable(widgets.hover)
  then
    pcall(
      widgets.hover
    )

    return
  end

  notify(
    "no debug hover backend is available",
    levels.WARN
  )
end

function M.scopes()
  local backend =
    native_backend()

  if backend ~= nil then
    local callback =
      method(
        backend,
        "scopes"
      )

    if callback ~= nil then
      protected_call(
        "scopes",
        callback
      )

      return
    end
  end

  local ok, widgets = pcall(
    require,
    "dap.widgets"
  )

  if
    ok
    and type(widgets) == "table"
    and callable(widgets.scopes)
  then
    pcall(
      widgets.scopes
    )

    return
  end

  notify(
    "no debug scopes backend is available",
    levels.WARN
  )
end

--
-- Status
--

function M.status()
  local bufnr =
    api.nvim_get_current_buf()

  local filetype =
    M.filetype(bufnr)

  local loaded =
    M.loaded()

  local failed =
    M.failed()

  local applicable = {}

  for _, spec in ipairs(MODULES) do
    if spec_matches_filetype(
      spec,
      filetype
    ) then
      local root =
        spec_root(
          spec,
          bufnr
        )

      if spec_enabled(
        spec,
        bufnr,
        root
      ) then
        applicable[#applicable + 1] =
          ("%s [%s]"):format(
            spec.module,
            root
          )
      end
    end
  end

  table.sort(applicable)

  notify(
    table.concat({
      "backend: "
        .. (
          M.backend_available()
              and "available"
            or "unavailable"
        ),

      "filetype: "
        .. (
          filetype ~= ""
              and filetype
            or "none"
        ),

      "root: "
        .. M.root(bufnr),

      "applicable modules: "
        .. (
          #applicable > 0
              and table.concat(
                applicable,
                ", "
              )
            or "none"
        ),

      "registered adapters: "
        .. tostring(
          vim.tbl_count(
            registry.adapters
          )
        ),

      "configuration filetypes: "
        .. tostring(
          vim.tbl_count(
            registry.configurations
          )
        ),

      "loaded modules: "
        .. (
          #loaded > 0
              and table.concat(
                loaded,
                ", "
              )
            or "none"
        ),

      "failed modules: "
        .. (
          #failed > 0
              and table.concat(
                failed,
                ", "
              )
            or "none"
        ),
    }, "\n")
  )
end

--
-- Core commands
--

local function create_commands()
  ---@type table<string, DebugCommand>
  local commands = {
    DebugBreakpoint = {
      callback = function()
        M.toggle_breakpoint()
      end,

      desc =
        "Toggle debug breakpoint",
    },

    DebugBreakpointClear = {
      callback = function()
        M.clear_breakpoints()
      end,

      desc =
        "Clear all debug breakpoints",
    },

    DebugBreakpointCondition = {
      callback = function()
        M.set_conditional_breakpoint()
      end,

      desc =
        "Set conditional breakpoint",
    },

    DebugContinue = {
      callback = function()
        M.continue()
      end,

      desc =
        "Continue debug session",
    },

    DebugDisconnect = {
      callback = function()
        M.disconnect()
      end,

      desc =
        "Disconnect debug session",
    },

    DebugHover = {
      callback = function()
        M.hover()
      end,

      desc =
        "Inspect value under cursor",
    },

    DebugLoad = {
      callback = function(args)
        M.load(
          args.args,
          api.nvim_get_current_buf()
        )
      end,

      complete = function()
        return module_names()
      end,

      desc =
        "Load debug adapter module",

      nargs = 1,
    },

    DebugLogpoint = {
      callback = function()
        M.set_logpoint()
      end,

      desc =
        "Set debug logpoint",
    },

    DebugPause = {
      callback = function()
        M.pause()
      end,

      desc =
        "Pause debug session",
    },

    DebugRepl = {
      callback = function()
        M.repl()
      end,

      desc =
        "Open debug REPL",
    },

    DebugRestart = {
      callback = function()
        M.restart()
      end,

      desc =
        "Restart debug session",
    },

    DebugRun = {
      callback = function()
        M.run()
      end,

      desc =
        "Start debug session",
    },

    DebugRunLast = {
      callback = function()
        M.run_last()
      end,

      desc =
        "Run previous debug configuration",
    },

    DebugScopes = {
      callback = function()
        M.scopes()
      end,

      desc =
        "Show debug scopes",
    },

    DebugStatus = {
      callback = function()
        M.status()
      end,

      desc =
        "Show native debug status",
    },

    DebugStepBack = {
      callback = function()
        M.step_back()
      end,

      desc =
        "Step backward",
    },

    DebugStepInto = {
      callback = function()
        M.step_into()
      end,

      desc =
        "Step into",
    },

    DebugStepOut = {
      callback = function()
        M.step_out()
      end,

      desc =
        "Step out",
    },

    DebugStepOver = {
      callback = function()
        M.step_over()
      end,

      desc =
        "Step over",
    },

    DebugStop = {
      callback = function()
        M.stop()
      end,

      desc =
        "Stop debug session",
    },

    DebugTerminate = {
      callback = function()
        M.terminate()
      end,

      desc =
        "Terminate debuggee",
    },
  }

  register_commands(commands)
end

--
-- Core mappings
--

local function create_mappings()
  local function opts(desc)
    return {
      desc = desc,
      silent = true,
    }
  end

  vim.keymap.set(
    "n",
    "<F5>",
    M.run,
    opts(
      "Debug: Run / Continue"
    )
  )

  vim.keymap.set(
    "n",
    "<F6>",
    M.pause,
    opts(
      "Debug: Pause"
    )
  )

  vim.keymap.set(
    "n",
    "<F7>",
    M.run_last,
    opts(
      "Debug: Run last"
    )
  )

  vim.keymap.set(
    "n",
    "<F8>",
    M.toggle_breakpoint,
    opts(
      "Debug: Toggle breakpoint"
    )
  )

  vim.keymap.set(
    "n",
    "<F9>",
    M.terminate,
    opts(
      "Debug: Terminate"
    )
  )

  vim.keymap.set(
    "n",
    "<F10>",
    M.step_over,
    opts(
      "Debug: Step over"
    )
  )

  vim.keymap.set(
    "n",
    "<F11>",
    M.step_into,
    opts(
      "Debug: Step into"
    )
  )

  vim.keymap.set(
    "n",
    "<F12>",
    M.step_out,
    opts(
      "Debug: Step out"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dB",
    M.set_conditional_breakpoint,
    opts(
      "Debug: Conditional breakpoint"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>db",
    M.toggle_breakpoint,
    opts(
      "Debug: Breakpoint"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dc",
    M.continue,
    opts(
      "Debug: Continue"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dh",
    M.hover,
    opts(
      "Debug: Hover"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dl",
    M.set_logpoint,
    opts(
      "Debug: Logpoint"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dp",
    M.pause,
    opts(
      "Debug: Pause"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dr",
    M.run,
    opts(
      "Debug: Run"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dR",
    M.restart,
    opts(
      "Debug: Restart"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>ds",
    M.scopes,
    opts(
      "Debug: Scopes"
    )
  )

  vim.keymap.set(
    "n",
    "<leader>dt",
    M.terminate,
    opts(
      "Debug: Terminate"
    )
  )
end

--
-- Breakpoint persistence
--

---@param bufnr integer
local function persist_buffer_breakpoints(
  bufnr
)
  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    not ok
    or type(breakpoints) ~= "table"
    or not callable(breakpoints.save)
  then
    return
  end

  pcall(
    breakpoints.save,
    bufnr
  )
end

local function persist_all_breakpoints()
  local ok, breakpoints = pcall(
    require,
    "dap.breakpoints"
  )

  if
    not ok
    or type(breakpoints) ~= "table"
    or not callable(
      breakpoints.save_all
    )
  then
    return
  end

  pcall(
    breakpoints.save_all
  )
end

--
-- Teardown
--

local function teardown_modules()
  for module_name, module in pairs(
    modules
  ) do
    if
      type(module) == "table"
      and callable(module.teardown)
    then
      local ok, teardown_error =
        pcall(
          module.teardown
        )

      if not ok then
        notify(
          (
            "%s teardown failed: %s"
          ):format(
            module_name,
            tostring(
              teardown_error
            )
          ),
          levels.WARN
        )
      end
    end
  end
end

--
-- Autocommands
--

local function create_autocmds()
  api.nvim_create_autocmd(
    "FileType",
    {
      callback = function(args)
        if
          not api.nvim_buf_is_valid(
            args.buf
          )
        then
          return
        end

        M.load_filetype(
          vim.bo[args.buf].filetype,
          args.buf
        )
      end,

      desc =
        "Load project-aware native debug modules",

      group =
        augroup,
    }
  )

  api.nvim_create_autocmd(
    "BufEnter",
    {
      callback = function(args)
        if
          not api.nvim_buf_is_valid(
            args.buf
          )
        then
          return
        end

        local filetype =
          vim.bo[args.buf].filetype

        if filetype == "" then
          return
        end

        --
        -- FileType only fires when the filetype is assigned. BufEnter lets
        -- modules activate when moving between multiple project roots during
        -- the same Neovim session.
        --
        M.load_filetype(
          filetype,
          args.buf
        )
      end,

      desc =
        "Activate debug modules for current project root",

      group =
        augroup,
    }
  )

  api.nvim_create_autocmd(
    "BufWipeout",
    {
      callback = function(args)
        persist_buffer_breakpoints(
          args.buf
        )
      end,

      desc =
        "Persist debug breakpoints",

      group =
        augroup,
    }
  )

  api.nvim_create_autocmd(
    "VimLeavePre",
    {
      callback = function()
        persist_all_breakpoints()
        teardown_modules()
      end,

      desc =
        "Persist and teardown debug state",

      group =
        augroup,
    }
  )
end

--
-- Setup
--

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  if setup_complete then
    return
  end

  setup_complete = true

  create_autocmds()
  create_commands()

  if opts.mappings ~= false then
    create_mappings()
  end

  local bufnr =
    api.nvim_get_current_buf()

  local filetype =
    M.filetype(bufnr)

  if filetype ~= "" then
    M.load_filetype(
      filetype,
      bufnr
    )
  end

  if not M.backend_available() then
    vim.schedule(function()
      notify(
        "vim.debug is unavailable; adapter definitions remain available in the local registry",
        levels.DEBUG
      )
    end)
  end
end

M.setup()

return M