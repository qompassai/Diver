-- #################################################################
-- ~/.config/nvim/lua/dap/init.lua
-- Native Debug Adapter Configuration
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

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local uv = vim.uv

local M = {}

local MODULE_PREFIX = "dap."
local NOTIFY_PREFIX = "[debug] "

local augroup = api.nvim_create_augroup("NativeDebug", {
  clear = true,
})

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

---@class DebugRegistry
---@field adapters table<string, table>
---@field configurations table<string, table[]>

---@type DebugModuleSpec[]
local MODULES = {
  {
    filetypes = {
      "java",
      "kotlin",
      "rust",
    },
    module = "android",
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
      "go",
    },
    module = "go",
  },
  {
    filetypes = {
      "kotlin",
    },
    module = "kotlin",
  },
  {
    filetypes = {
      "c",
      "cpp",
      "objc",
      "objcpp",
      "rust",
      "swift",
      "zig",
    },
    module = "lldb",
  },
  {
    filetypes = {
      "lua",
    },
    module = "lua",
  },
  {
    filetypes = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
    },
    module = "node",
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
      "cs",
    },
    module = "unity",
  },
  {
    filetypes = {
      "zig",
    },
    module = "zig",
  },
}

---@type DebugRegistry
local registry = {
  adapters = {},
  configurations = {},
}

---@type table<string, boolean>
local failed_modules = {}

---@type table<string, boolean>
local loaded_modules = {}

---@type table<string, boolean>
local registered_commands = {}

---@type table<string, boolean>
local registered_mappings = {}

local setup_complete = false

--
-- `vim.debug` is not guaranteed to exist.
--
-- Never cache:
--
--   local debug = vim.debug
--
-- because doing so turns a missing experimental API into an immediate nil
-- dereference later. Always resolve it dynamically and validate the result.
--

---@return table?
local function native_backend()
  local candidate = rawget(vim, "debug")

  if type(candidate) ~= "table" then
    return nil
  end

  return candidate
end

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(NOTIFY_PREFIX .. message, level or levels.INFO)
end

---@param value unknown
---@return boolean
local function callable(value)
  return type(value) == "function"
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
  return type(value) == "string" and value ~= ""
end

---@param table_value table
---@param key string
---@return function?
local function method(table_value, key)
  local value = table_value[key]

  if not callable(value) then
    return nil
  end

  return value
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

---@param command string
---@return boolean
function M.executable(command)
  assert(nonempty_string(command), "command must be a non-empty string")

  return fn.executable(command) == 1
end

---@param path string
---@return boolean
function M.exists(path)
  assert(nonempty_string(path), "path must be a non-empty string")

  return uv.fs_stat(path) ~= nil
end

---@param path string
---@return string
function M.normalize(path)
  assert(type(path) == "string", "path must be a string")

  if path == "" then
    return ""
  end

  return fs.normalize(fn.fnamemodify(path, ":p"))
end

---@param bufnr? integer
---@return string
function M.filename(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  return M.normalize(api.nvim_buf_get_name(bufnr))
end

---@param bufnr? integer
---@return string
function M.filetype(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(bufnr) then
    return ""
  end

  return vim.bo[bufnr].filetype
end

---@param bufnr? integer
---@return string
function M.root(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local current_filename = M.filename(bufnr)

  if current_filename == "" then
    return fn.getcwd()
  end

  local detected_root = fs.root(current_filename, {
    ".git",
    ".hg",
    ".svn",
  })

  if type(detected_root) == "string" and detected_root ~= "" then
    return fs.normalize(detected_root)
  end

  return fs.dirname(current_filename) or fn.getcwd()
end

---@param name string
---@param callback unknown
---@param ... unknown
---@return boolean
---@return unknown?
local function protected_call(name, callback, ...)
  if not callable(callback) then
    return false, nil
  end

  local ok, result = pcall(callback, ...)

  if not ok then
    notify(("%s failed: %s"):format(name, tostring(result)), levels.ERROR)

    return false, nil
  end

  return true, result
end

---@param names string[]
---@param ... unknown
---@return boolean
---@return unknown?
local function backend_call_any(names, ...)
  local backend = native_backend()

  if backend == nil then
    notify("native DAP backend is unavailable", levels.WARN)

    return false, nil
  end

  for index = 1, #names do
    local name = names[index]

    local callback = method(backend, name)

    if callback ~= nil then
      return protected_call(name, callback, ...)
    end
  end

  notify(("native debug backend does not provide %s"):format(table.concat(names, " or ")), levels.WARN)

  return false, nil
end

---@param name string
---@param ... unknown
---@return boolean
---@return unknown?
local function backend_call(name, ...)
  return backend_call_any({
    name,
  }, ...)
end

---@param name string
---@param adapter table
---@return boolean
local function register_adapter(name, adapter)
  assert(nonempty_string(name), "adapter name must be non-empty")

  assert(type(adapter) == "table", "adapter must be a table")

  --
  -- Always retain the configuration locally. This makes the module registry
  -- usable even when the current Neovim build has no native DAP backend.
  --
  registry.adapters[name] = adapter

  local backend = native_backend()

  if backend == nil then
    return false
  end

  if type(backend.adapters) == "table" then
    backend.adapters[name] = adapter

    return true
  end

  local callback = method(backend, "register_adapter")

  if callback == nil then
    return false
  end

  local ok = protected_call("register_adapter", callback, name, adapter)

  return ok
end

---@param filetype string
---@param configurations table[]
---@return boolean
local function register_configurations(filetype, configurations)
  assert(nonempty_string(filetype), "filetype must be non-empty")

  assert(type(configurations) == "table", "configurations must be a table")

  registry.configurations[filetype] = configurations

  local backend = native_backend()

  if backend == nil then
    return false
  end

  if type(backend.configurations) == "table" then
    backend.configurations[filetype] = configurations

    return true
  end

  local callback = method(backend, "register_configuration")

  if callback == nil then
    return false
  end

  local success = true

  for index = 1, #configurations do
    local ok = protected_call("register_configuration", callback, filetype, configurations[index])

    if not ok then
      success = false
    end
  end

  return success
end

---@param name string
---@param spec DebugCommand
local function register_command(name, spec)
  if registered_commands[name] then
    return
  end

  if not nonempty_string(name) or type(spec) ~= "table" or not callable(spec.callback) then
    return
  end

  local existing = api.nvim_get_commands({
    builtin = false,
  })

  if existing[name] ~= nil then
    registered_commands[name] = true

    return
  end

  api.nvim_create_user_command(name, spec.callback, {
    bang = spec.bang == true,

    complete = spec.complete,

    desc = spec.desc,

    nargs = spec.nargs or 0,
  })

  registered_commands[name] = true
end

---@param commands table<string, DebugCommand>
local function register_commands(commands)
  for name, spec in pairs(commands) do
    register_command(name, spec)
  end
end

---@param name string
---@param spec DebugMapping
local function register_mapping(name, spec)
  if registered_mappings[name] then
    return
  end

  if type(spec) ~= "table" or not nonempty_string(spec.lhs) then
    return
  end

  local rhs = spec.rhs

  if type(rhs) ~= "string" and not callable(rhs) then
    return
  end

  vim.keymap.set(spec.mode or "n", spec.lhs, rhs, {
    desc = spec.desc,

    silent = true,
  })

  registered_mappings[name] = true
end

---@param mappings table<string, DebugMapping>
local function register_mappings(mappings)
  for name, spec in pairs(mappings) do
    register_mapping(name, spec)
  end
end

---@param module DebugModule
local function register_module(module)
  if type(module.adapters) == "table" then
    for name, adapter in pairs(module.adapters) do
      if nonempty_string(name) and type(adapter) == "table" then
        register_adapter(name, adapter)
      end
    end
  end

  if type(module.adapter) == "table" then
    local name = module.adapter.name

    if nonempty_string(name) then
      register_adapter(name, module.adapter)
    end
  end

  if type(module.configurations) == "table" then
    for filetype, configurations in pairs(module.configurations) do
      if nonempty_string(filetype) and type(configurations) == "table" then
        register_configurations(filetype, configurations)
      end
    end
  end

  if type(module.commands) == "table" then
    register_commands(module.commands)
  end

  if type(module.mappings) == "table" then
    register_mappings(module.mappings)
  end

  if callable(module.setup) then
    local backend = native_backend()

    local ok, setup_error = pcall(module.setup, {
      backend = backend,
      debug = backend,
      root = M.root(),
    })

    if not ok then
      notify(("module setup failed: %s"):format(tostring(setup_error)), levels.ERROR)
    end
  end
end

---@param module_name string
---@return boolean
function M.load(module_name)
  assert(nonempty_string(module_name), "module_name must be non-empty")

  if loaded_modules[module_name] then
    return true
  end

  if failed_modules[module_name] then
    return false
  end

  local ok, module = pcall(require, MODULE_PREFIX .. module_name)

  if not ok then
    failed_modules[module_name] = true

    notify(("failed to load %s: %s"):format(module_name, tostring(module)), levels.WARN)

    return false
  end

  if type(module) ~= "table" then
    failed_modules[module_name] = true

    notify(("%s must return a table"):format(module_name), levels.ERROR)

    return false
  end

  register_module(module)

  loaded_modules[module_name] = true

  return true
end

---@param filetype string
function M.load_filetype(filetype)
  if filetype == "" then
    return
  end

  for index = 1, #MODULES do
    local spec = MODULES[index]

    for filetype_index = 1, #spec.filetypes do
      if spec.filetypes[filetype_index] == filetype then
        M.load(spec.module)

        break
      end
    end
  end
end

---@return string[]
function M.loaded()
  local result = {}

  for module_name, loaded in pairs(loaded_modules) do
    if loaded then
      result[#result + 1] = module_name
    end
  end

  table.sort(result)

  return result
end

---@return string[]
function M.failed()
  local result = {}

  for module_name, failed in pairs(failed_modules) do
    if failed then
      result[#result + 1] = module_name
    end
  end

  table.sort(result)

  return result
end

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
  backend_call("pause")
end

function M.restart()
  local backend = native_backend()

  if backend == nil then
    notify("native DAP backend is unavailable", levels.WARN)

    return
  end

  local callback = method(backend, "restart")

  if callback ~= nil then
    protected_call("restart", callback)

    return
  end

  local stop_callback = method(backend, "stop") or method(backend, "terminate")

  local run_callback = method(backend, "run_last") or method(backend, "run") or method(backend, "start")

  if stop_callback == nil or run_callback == nil then
    notify("native debug backend cannot restart sessions", levels.WARN)

    return
  end

  local ok = protected_call("stop", stop_callback)

  if not ok then
    return
  end

  vim.schedule(function()
    protected_call("run", run_callback)
  end)
end

function M.run()
  local filetype = M.filetype()

  M.load_filetype(filetype)

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

function M.toggle_breakpoint()
  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "toggle_breakpoint") or method(backend, "toggleBreakpoint")

    if callback ~= nil then
      protected_call("toggle_breakpoint", callback)

      return
    end
  end

  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if ok and type(breakpoints) == "table" and callable(breakpoints.toggle) then
    local success, breakpoint_error = pcall(breakpoints.toggle)

    if not success then
      notify(("breakpoint toggle failed: %s"):format(tostring(breakpoint_error)), levels.ERROR)
    end

    return
  end

  notify("no breakpoint backend is available", levels.WARN)
end

function M.clear_breakpoints()
  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "clear_breakpoints") or method(backend, "clearBreakpoints")

    if callback ~= nil then
      protected_call("clear_breakpoints", callback)

      return
    end
  end

  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if ok and type(breakpoints) == "table" and callable(breakpoints.clear) then
    pcall(breakpoints.clear)

    return
  end

  notify("no breakpoint backend is available", levels.WARN)
end

function M.set_conditional_breakpoint()
  local condition = fn.input("Breakpoint condition: ")

  if condition == "" then
    return
  end

  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "set_breakpoint") or method(backend, "setBreakpoint")

    if callback ~= nil then
      protected_call("set_breakpoint", callback, {
        condition = condition,
      })

      return
    end
  end

  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if ok and type(breakpoints) == "table" and callable(breakpoints.set) then
    pcall(breakpoints.set, {
      condition = condition,
    })

    return
  end

  notify("no breakpoint backend is available", levels.WARN)
end

function M.set_logpoint()
  local message = fn.input("Log point message: ")

  if message == "" then
    return
  end

  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "set_breakpoint") or method(backend, "setBreakpoint")

    if callback ~= nil then
      protected_call("set_breakpoint", callback, {
        log_message = message,
        logMessage = message,
      })

      return
    end
  end

  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if ok and type(breakpoints) == "table" and callable(breakpoints.set) then
    pcall(breakpoints.set, {
      log_message = message,
      logMessage = message,
    })

    return
  end

  notify("no breakpoint backend is available", levels.WARN)
end

function M.repl()
  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "repl")

    if callback ~= nil then
      protected_call("repl", callback)

      return
    end
  end

  local ok, widgets = pcall(require, "dap.widgets")

  if ok and type(widgets) == "table" and callable(widgets.repl) then
    pcall(widgets.repl)

    return
  end

  notify("no debug REPL backend is available", levels.WARN)
end

function M.hover()
  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "hover")

    if callback ~= nil then
      protected_call("hover", callback)

      return
    end
  end

  local ok, widgets = pcall(require, "dap.widgets")

  if ok and type(widgets) == "table" and callable(widgets.hover) then
    pcall(widgets.hover)

    return
  end

  notify("no debug hover backend is available", levels.WARN)
end

function M.scopes()
  local backend = native_backend()

  if backend ~= nil then
    local callback = method(backend, "scopes")

    if callback ~= nil then
      protected_call("scopes", callback)

      return
    end
  end

  local ok, widgets = pcall(require, "dap.widgets")

  if ok and type(widgets) == "table" and callable(widgets.scopes) then
    pcall(widgets.scopes)

    return
  end

  notify("no debug scopes backend is available", levels.WARN)
end

function M.status()
  local backend = native_backend()

  local backend_status = backend ~= nil and "available" or "unavailable"

  local loaded = M.loaded()

  local failed = M.failed()

  notify(table.concat({
    "backend: " .. backend_status,

    "adapters: " .. tostring(vim.tbl_count(registry.adapters)),

    "configurations: " .. tostring(vim.tbl_count(registry.configurations)),

    "loaded modules: " .. (#loaded > 0 and table.concat(loaded, ", ") or "none"),

    "failed modules: " .. (#failed > 0 and table.concat(failed, ", ") or "none"),
  }, "\n"))
end

local function create_commands()
  ---@type table<string, DebugCommand>
  local commands = {
    DebugBreakpoint = {
      callback = function()
        M.toggle_breakpoint()
      end,
      desc = "Toggle debug breakpoint",
    },

    DebugBreakpointClear = {
      callback = function()
        M.clear_breakpoints()
      end,
      desc = "Clear all debug breakpoints",
    },

    DebugBreakpointCondition = {
      callback = function()
        M.set_conditional_breakpoint()
      end,
      desc = "Set conditional breakpoint",
    },

    DebugContinue = {
      callback = function()
        M.continue()
      end,
      desc = "Continue debug session",
    },

    DebugDisconnect = {
      callback = function()
        M.disconnect()
      end,
      desc = "Disconnect debug session",
    },

    DebugHover = {
      callback = function()
        M.hover()
      end,
      desc = "Inspect value under cursor",
    },

    DebugLoad = {
      callback = function(args)
        M.load(args.args)
      end,

      complete = function()
        local modules = {}

        for index = 1, #MODULES do
          modules[#modules + 1] = MODULES[index].module
        end

        table.sort(modules)

        return modules
      end,

      desc = "Load debug adapter module",
      nargs = 1,
    },

    DebugLogpoint = {
      callback = function()
        M.set_logpoint()
      end,
      desc = "Set debug logpoint",
    },

    DebugPause = {
      callback = function()
        M.pause()
      end,
      desc = "Pause debug session",
    },

    DebugRepl = {
      callback = function()
        M.repl()
      end,
      desc = "Open debug REPL",
    },

    DebugRestart = {
      callback = function()
        M.restart()
      end,
      desc = "Restart debug session",
    },

    DebugRun = {
      callback = function()
        M.run()
      end,
      desc = "Start debug session",
    },

    DebugRunLast = {
      callback = function()
        M.run_last()
      end,
      desc = "Run previous debug configuration",
    },

    DebugScopes = {
      callback = function()
        M.scopes()
      end,
      desc = "Show debug scopes",
    },

    DebugStatus = {
      callback = function()
        M.status()
      end,
      desc = "Show native debug status",
    },

    DebugStepBack = {
      callback = function()
        M.step_back()
      end,
      desc = "Step backward",
    },

    DebugStepInto = {
      callback = function()
        M.step_into()
      end,
      desc = "Step into",
    },

    DebugStepOut = {
      callback = function()
        M.step_out()
      end,
      desc = "Step out",
    },

    DebugStepOver = {
      callback = function()
        M.step_over()
      end,
      desc = "Step over",
    },

    DebugStop = {
      callback = function()
        M.stop()
      end,
      desc = "Stop debug session",
    },

    DebugTerminate = {
      callback = function()
        M.terminate()
      end,
      desc = "Terminate debuggee",
    },
  }

  register_commands(commands)
end

local function create_mappings()
  local function opts(desc)
    return {
      desc = desc,
      silent = true,
    }
  end

  vim.keymap.set("n", "<F5>", M.run, opts("Debug: Run / Continue"))

  vim.keymap.set("n", "<F6>", M.pause, opts("Debug: Pause"))

  vim.keymap.set("n", "<F7>", M.run_last, opts("Debug: Run last"))

  vim.keymap.set("n", "<F8>", M.toggle_breakpoint, opts("Debug: Toggle breakpoint"))

  vim.keymap.set("n", "<F9>", M.terminate, opts("Debug: Terminate"))

  vim.keymap.set("n", "<F10>", M.step_over, opts("Debug: Step over"))

  vim.keymap.set("n", "<F11>", M.step_into, opts("Debug: Step into"))

  vim.keymap.set("n", "<F12>", M.step_out, opts("Debug: Step out"))

  vim.keymap.set("n", "<leader>dB", M.set_conditional_breakpoint, opts("Debug: Conditional breakpoint"))

  vim.keymap.set("n", "<leader>db", M.toggle_breakpoint, opts("Debug: Breakpoint"))

  vim.keymap.set("n", "<leader>dc", M.continue, opts("Debug: Continue"))

  vim.keymap.set("n", "<leader>dh", M.hover, opts("Debug: Hover"))

  vim.keymap.set("n", "<leader>dl", M.set_logpoint, opts("Debug: Logpoint"))

  vim.keymap.set("n", "<leader>dp", M.pause, opts("Debug: Pause"))

  vim.keymap.set("n", "<leader>dr", M.run, opts("Debug: Run"))

  vim.keymap.set("n", "<leader>dR", M.restart, opts("Debug: Restart"))

  vim.keymap.set("n", "<leader>ds", M.scopes, opts("Debug: Scopes"))

  vim.keymap.set("n", "<leader>dt", M.terminate, opts("Debug: Terminate"))
end

local function persist_buffer_breakpoints(bufnr)
  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if not ok or type(breakpoints) ~= "table" or not callable(breakpoints.save) then
    return
  end

  pcall(breakpoints.save, bufnr)
end

local function persist_all_breakpoints()
  local ok, breakpoints = pcall(require, "dap.breakpoints")

  if not ok or type(breakpoints) ~= "table" or not callable(breakpoints.save_all) then
    return
  end

  pcall(breakpoints.save_all)
end

local function teardown_modules()
  for module_name, loaded in pairs(loaded_modules) do
    if loaded then
      local module = package.loaded[MODULE_PREFIX .. module_name]

      if type(module) == "table" and callable(module.teardown) then
        pcall(module.teardown)
      end
    end
  end
end

local function create_autocmds()
  api.nvim_create_autocmd("FileType", {
    callback = function(args)
      if not api.nvim_buf_is_valid(args.buf) then
        return
      end

      local filetype = vim.bo[args.buf].filetype

      M.load_filetype(filetype)
    end,

    desc = "Load debug adapter for filetype",

    group = augroup,
  })

  api.nvim_create_autocmd("BufWipeout", {
    callback = function(args)
      persist_buffer_breakpoints(args.buf)
    end,

    desc = "Persist debug breakpoints",

    group = augroup,
  })

  api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      persist_all_breakpoints()
      teardown_modules()
    end,

    desc = "Persist and teardown debug state",

    group = augroup,
  })
end

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

  local current_filetype = M.filetype()

  if current_filetype ~= "" then
    M.load_filetype(current_filetype)
  end
  if not M.backend_available() then
    vim.schedule(function()
      notify("vim.debug is unavailable; adapter definitions loaded into the local registry only", levels.DEBUG)
    end)
  end
end

M.setup()

return M
