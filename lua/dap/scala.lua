-- #################################################################
-- ~/.config/nvim/lua/dap/scala.lua
-- Qompass AI Diver Native Scala Debug Adapter Configuration
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
---@source https://github.com/scalameta/metals
---@source https://scalameta.org/metals/docs/integrations/new-editor/
---@source https://github.com/scalacenter/scala-debug-adapter
---@source https://github.com/scalacenter/bloop

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local lsp = vim.lsp
local uv = vim.uv

local M = {}

local SOURCE = "scala-dap"
local METALS_COMMAND = "debug-adapter-start"
local METALS_TIMEOUT_MS = 30000
local DEFAULT_ATTACH_HOST = "127.0.0.1"
local DEFAULT_ATTACH_PORT = 5005

---@type string[]
local ROOT_MARKERS = {
  ".bloop",
  ".metals",
  ".scala-build",
  ".bsp",
  "build.sbt",
  "build.sc",
  "build.mill",
  "project/build.properties",
  "project/build.sbt",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
  "scala-cli.conf",
  ".git",
}

---@class ScalaDapEndpoint
---@field host string
---@field port integer
---@field uri string

---@class ScalaDapState
---@field root string?
---@field endpoint ScalaDapEndpoint?
---@field endpoint_key string?
local state = {
  endpoint = nil,
  endpoint_key = nil,
  root = nil,
}

---@param message string
---@param level? integer
local function notify(message, level)
  vim.notify(
    ("[%s] %s"):format(
      SOURCE,
      message
    ),
    level or levels.INFO
  )
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
    fn.fnamemodify(path, ":p")
  )
end

---@param path string
---@return boolean
local function directory(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "directory"
end

---@param path string
---@return boolean
local function file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat = uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "file"
end

---@param bufnr? integer
---@return string
local function filename(bufnr)
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
local function project_root(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local current = filename(bufnr)

  if current ~= "" then
    local detected = fs.root(
      current,
      ROOT_MARKERS
    )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(detected)
    end

    local parent = fs.dirname(current)

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(parent)
    end
  end

  return fs.normalize(
    fn.getcwd()
  )
end

---@param client vim.lsp.Client
---@return boolean
local function is_metals(client)
  return type(client) == "table"
    and type(client.name) == "string"
    and client.name:lower() == "metals"
end

---@param bufnr? integer
---@return vim.lsp.Client?
local function metals_client(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local clients = lsp.get_clients({
    bufnr = bufnr,
  })

  for _, client in ipairs(clients) do
    if is_metals(client) then
      return client
    end
  end

  --
  -- A Scala metadata/build buffer may not itself have Metals attached even
  -- though Metals is active for the workspace. Fall back to a root match.
  --
  local root = project_root(bufnr)

  clients = lsp.get_clients()

  for _, client in ipairs(clients) do
    if is_metals(client) then
      local client_root = client.root_dir

      if
        nonempty_string(client_root)
        and fs.normalize(client_root) == root
      then
        return client
      end
    end
  end

  return nil
end

---@return string[]
local function prompt_args()
  local input = fn.input(
    "Scala arguments: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string[]
local function prompt_jvm_options()
  local input = fn.input(
    "JVM options: "
  )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string?
local function prompt_env_file()
  local root = project_root()

  local selected = fn.input(
    "Environment file: ",
    fs.joinpath(root, ".env"),
    "file"
  )

  if selected == "" then
    return nil
  end

  selected = normalize(
    fn.expand(selected)
  )

  if not file(selected) then
    notify(
      ("environment file does not exist: %s"):format(
        selected
      ),
      levels.ERROR
    )

    return nil
  end

  return selected
end

---@return string
local function prompt_main_class()
  return fn.input(
    "Scala main class: "
  )
end

---@return string
local function prompt_test_class()
  return fn.input(
    "Scala test class: "
  )
end

---@return string?
local function prompt_build_target()
  local target = fn.input(
    "Metals build target (blank = auto): "
  )

  if target == "" then
    return nil
  end

  return target
end

---@return string
local function prompt_attach_host()
  local host = fn.input(
    "JVM debug host: ",
    DEFAULT_ATTACH_HOST
  )

  if host == "" then
    return DEFAULT_ATTACH_HOST
  end

  return host
end

---@return integer
local function prompt_attach_port()
  local value = fn.input(
    "JVM debug port: ",
    tostring(DEFAULT_ATTACH_PORT)
  )

  local port = tonumber(value)

  if
    port == nil
    or port < 1
    or port > 65535
  then
    notify(
      ("invalid JVM debug port: %s"):format(
        value
      ),
      levels.ERROR
    )

    return DEFAULT_ATTACH_PORT
  end

  return math.floor(port)
end

---@param params table
---@return table
local function optional_runtime_fields(params)
  local args = prompt_args()
  local jvm_options = prompt_jvm_options()

  if #args > 0 then
    params.args = args
  end

  if #jvm_options > 0 then
    params.jvmOptions = jvm_options
  end

  return params
end

---@return table
local function current_run_or_test_params()
  return {
    path = filename(),

    runType = "runOrTestFile",
  }
end

---@return table
local function current_run_params()
  return {
    path = filename(),

    runType = "run",
  }
end

---@return table
local function current_test_params()
  return {
    path = filename(),

    runType = "testFile",
  }
end

---@return table
local function test_target_params()
  return {
    path = filename(),

    runType = "testTarget",
  }
end

---@return table
local function current_with_args_params()
  return optional_runtime_fields({
    path = filename(),

    runType = "runOrTestFile",
  })
end

---@return table
local function current_with_env_params()
  local params = optional_runtime_fields({
    path = filename(),

    runType = "runOrTestFile",
  })

  local env_file = prompt_env_file()

  if env_file ~= nil then
    params.envFile = env_file
  end

  return params
end

---@return table
local function main_class_params()
  local params = optional_runtime_fields({
    mainClass = prompt_main_class(),
  })

  local target = prompt_build_target()

  if target ~= nil then
    params.buildTarget = target
  end

  return params
end

---@return table
local function test_class_params()
  local params = optional_runtime_fields({
    testClass = prompt_test_class(),
  })

  local target = prompt_build_target()

  if target ~= nil then
    params.buildTarget = target
  end

  return params
end

---@return table
local function attach_params()
  local params = {
    hostName = prompt_attach_host(),

    port = prompt_attach_port(),
  }

  local target = prompt_build_target()

  if target ~= nil then
    params.buildTarget = target
  end

  return params
end

---@param value unknown
---@return string?
local function endpoint_uri(value)
  if type(value) == "string" then
    return value
  end

  if type(value) ~= "table" then
    return nil
  end

  return value.uri
    or value.address
    or value.endpoint
end

---@param uri string
---@return ScalaDapEndpoint?
local function parse_endpoint(uri)
  if not nonempty_string(uri) then
    return nil
  end

  local host, port = uri:match(
    "^tcp://([^:/]+):(%d+)/?$"
  )

  if host == nil then
    host, port = uri:match(
      "^([^:/]+):(%d+)$"
    )
  end

  if
    host == nil
    or port == nil
  then
    return nil
  end

  local numeric_port = tonumber(port)

  if
    numeric_port == nil
    or numeric_port < 1
    or numeric_port > 65535
  then
    return nil
  end

  return {
    host = host,

    port = math.floor(numeric_port),

    uri = uri,
  }
end

---@param params table
---@return ScalaDapEndpoint?
local function start_metals_session(params)
  local bufnr = api.nvim_get_current_buf()
  local client = metals_client(bufnr)

  if client == nil then
    notify(
      table.concat({
        "Metals is not attached to this Scala workspace.",
        "",
        "The Scala DAP requires an active Metals LSP client because",
        "`debug-adapter-start` is the DAP session broker.",
      }, "\n"),
      levels.ERROR
    )

    return nil
  end

  local response = client:request_sync(
    "workspace/executeCommand",
    {
      command = METALS_COMMAND,

      arguments = {
        params,
      },
    },
    METALS_TIMEOUT_MS,
    bufnr
  )

  if response == nil then
    notify(
      "Metals did not respond to debug-adapter-start",
      levels.ERROR
    )

    return nil
  end

  if response.err ~= nil then
    notify(
      ("Metals debug-adapter-start failed: %s"):format(
        vim.inspect(response.err)
      ),
      levels.ERROR
    )

    return nil
  end

  local uri = endpoint_uri(
    response.result
  )

  if uri == nil then
    notify(
      (
        "Metals returned an unexpected debug endpoint: %s"
      ):format(
        vim.inspect(response.result)
      ),
      levels.ERROR
    )

    return nil
  end

  local endpoint = parse_endpoint(uri)

  if endpoint == nil then
    notify(
      ("invalid Metals DAP endpoint: %s"):format(
        uri
      ),
      levels.ERROR
    )

    return nil
  end

  state.endpoint = endpoint

  return endpoint
end

---@param key string
---@param params fun(): table
---@return integer
local function adapter_port(
  key,
  params
)
  --
  -- Each call to `debug-adapter-start` creates a new debug server. Do not
  -- retain endpoints across different configurations.
  --
  state.endpoint = nil
  state.endpoint_key = key

  local endpoint =
    start_metals_session(params())

  if endpoint == nil then
    return 0
  end

  return endpoint.port
end

---@param key string
---@param params fun(): table
---@return table
local function adapter(
  key,
  params
)
  return {
    name = key,

    type = "server",

    host = "127.0.0.1",

    port = function()
      return adapter_port(
        key,
        params
      )
    end,

    options = {
      source_filetype = "scala",
    },
  }
end

local function metals_command(
  command,
  arguments
)
  local client = metals_client()

  if client == nil then
    notify(
      "Metals LSP is not attached",
      levels.ERROR
    )

    return
  end

  client:request(
    "workspace/executeCommand",
    {
      command = command,

      arguments = arguments or {},
    },
    function(error)
      if error ~= nil then
        notify(
          ("%s failed: %s"):format(
            command,
            vim.inspect(error)
          ),
          levels.ERROR
        )
      end
    end
  )
end

local function reconnect_build_server()
  metals_command(
    "metals-build-connect"
  )
end

local function show_status()
  local root = project_root()
  local client = metals_client()

  local bloop_directory =
    fs.joinpath(
      root,
      ".bloop"
    )

  local bsp_directory =
    fs.joinpath(
      root,
      ".bsp"
    )

  notify(
    table.concat({
      "root: "
        .. root,

      "Metals LSP: "
        .. (
          client ~= nil
              and (
                "%s [id=%d]"
              ):format(
                client.name,
                client.id
              )
            or "not attached"
        ),

      ".bloop: "
        .. (
          directory(bloop_directory)
              and "present"
            or "absent"
        ),

      ".bsp: "
        .. (
          directory(bsp_directory)
              and "present"
            or "absent"
        ),

      "session broker: "
        .. METALS_COMMAND,

      "last DAP endpoint: "
        .. (
          state.endpoint ~= nil
              and state.endpoint.uri
            or "none"
        ),
    }, "\n"),
    client ~= nil
        and levels.INFO
      or levels.WARN
  )
end

---@type table<string, table>
M.adapters = {
  ["scala-run-or-test"] = adapter(
    "scala-run-or-test",
    current_run_or_test_params
  ),

  ["scala-run"] = adapter(
    "scala-run",
    current_run_params
  ),

  ["scala-test-file"] = adapter(
    "scala-test-file",
    current_test_params
  ),

  ["scala-test-target"] = adapter(
    "scala-test-target",
    test_target_params
  ),

  ["scala-with-args"] = adapter(
    "scala-with-args",
    current_with_args_params
  ),

  ["scala-with-env"] = adapter(
    "scala-with-env",
    current_with_env_params
  ),

  ["scala-main-class"] = adapter(
    "scala-main-class",
    main_class_params
  ),

  ["scala-test-class"] = adapter(
    "scala-test-class",
    test_class_params
  ),

  ["scala-attach"] = adapter(
    "scala-attach",
    attach_params
  ),
}

---@type table<string, table[]>
M.configurations = {
  scala = {
    {
      name = "Scala: Run or Test Current File",

      type = "scala-run-or-test",

      request = "launch",
    },

    {
      name = "Scala: Run Current File",

      type = "scala-run",

      request = "launch",
    },

    {
      name = "Scala: Test Current File",

      type = "scala-test-file",

      request = "launch",
    },

    {
      name = "Scala: Test Current Target",

      type = "scala-test-target",

      request = "launch",
    },

    {
      name = "Scala: Current File with Arguments",

      type = "scala-with-args",

      request = "launch",
    },

    {
      name = "Scala: Current File with JVM Options / Env",

      type = "scala-with-env",

      request = "launch",
    },

    {
      name = "Scala: Main Class",

      type = "scala-main-class",

      request = "launch",
    },

    {
      name = "Scala: Test Class",

      type = "scala-test-class",

      request = "launch",
    },

    {
      name = "Scala: Attach Remote JVM",

      type = "scala-attach",

      request = "attach",
    },
  },
}

---@type table<string, DebugCommand>
M.commands = {
  ScalaDebugBuildConnect = {
    callback = function()
      reconnect_build_server()
    end,

    desc = "Reconnect Metals to Scala build server",
  },

  ScalaDebugStatus = {
    callback = function()
      show_status()
    end,

    desc = "Show Scala debug status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  scala_debug_build_connect = {
    lhs = "<leader>dSb",

    mode = "n",

    rhs = function()
      reconnect_build_server()
    end,

    desc = "Debug Scala: Reconnect build server",
  },

  scala_debug_status = {
    lhs = "<leader>dSs",

    mode = "n",

    rhs = function()
      show_status()
    end,

    desc = "Debug Scala: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  if metals_client() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Metals is not currently attached.",
          "",
          "Scala DAP definitions were registered, but debugging",
          "requires the native Metals LSP client to be attached first.",
        }, "\n"),
        levels.DEBUG
      )
    end)
  end
end

---@return string
function M.root()
  return project_root()
end

---@return vim.lsp.Client?
function M.metals()
  return metals_client()
end

---@return ScalaDapEndpoint?
function M.endpoint()
  return state.endpoint
end

return M