-- #################################################################
-- ~/.config/nvim/lua/dap/java.lua
-- Qompass AI Diver Native Java Debug Adapter Configuration
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
---@source https://github.com/microsoft/java-debug
---@source https://github.com/microsoft/vscode-java-debug
---@source https://github.com/eclipse-jdtls/eclipse.jdt.ls
---@source https://docs.oracle.com/javase/8/docs/technotes/guides/jpda/jdwp-spec.html

local api = vim.api
local fn = vim.fn
local fs = vim.fs
local levels = vim.log.levels
local lsp = vim.lsp
local uv = vim.uv

local M = {}

local SOURCE = "java-dap"

local DEBUG_SESSION_COMMAND =
  "vscode.java.startDebugSession"

local DEBUG_SESSION_TIMEOUT_MS = 30000

local DEFAULT_JDWP_HOST =
  "127.0.0.1"

local DEFAULT_JDWP_PORT =
  5005

---@type string[]
local ROOT_MARKERS = {
  "pom.xml",

  "mvnw",

  "build.gradle",

  "build.gradle.kts",

  "gradlew",

  "settings.gradle",

  "settings.gradle.kts",

  "build.xml",

  ".classpath",

  ".project",

  "module-info.java",

  "WORKSPACE",

  "WORKSPACE.bazel",

  "BUILD",

  "BUILD.bazel",

  ".git",
}

---@type string[]
local JAVA_VERSION_FILES = {
  ".java-version",

  ".sdkmanrc",

  ".tool-versions",
}

---@type string[]
local STEP_SKIP_CLASSES = {
  "$JDK",

  "$Libraries",

  "java.*",

  "javax.*",

  "jdk.*",

  "sun.*",

  "com.sun.*",
}

---@class JavaDapEndpoint
---@field host string
---@field port integer

---@class JavaDapState
---@field endpoint JavaDapEndpoint?
---@field java string?
---@field java_home string?
---@field root string?
local state = {
  endpoint = nil,

  java = nil,

  java_home = nil,

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
---@return boolean
local function is_file(path)
  if not nonempty_string(path) then
    return false
  end

  local stat =
    uv.fs_stat(path)

  return stat ~= nil
    and stat.type == "file"
end

---@param path string
---@return boolean
local function executable(path)
  return nonempty_string(path)
    and fn.executable(path) == 1
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

---@param command string
---@return string?
local function executable_path(command)
  local path =
    fn.exepath(command)

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
    return ""
  end

  local name =
    api.nvim_buf_get_name(bufnr)

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

  local current =
    filename(bufnr)

  if current ~= "" then
    local detected =
      fs.root(
        current,
        ROOT_MARKERS
      )

    if
      type(detected) == "string"
      and detected ~= ""
    then
      return fs.normalize(
        detected
      )
    end

    local parent =
      fs.dirname(current)

    if
      type(parent) == "string"
      and parent ~= ""
    then
      return fs.normalize(
        parent
      )
    end
  end

  return fs.normalize(
    fn.getcwd()
  )
end

---@param client vim.lsp.Client
---@return boolean
local function is_jdtls(client)
  if type(client) ~= "table" then
    return false
  end

  local name =
    type(client.name) == "string"
      and client.name:lower()
      or ""

  return name == "jdtls"
    or name == "eclipse.jdt.ls"
    or name == "eclipse-jdtls"
end

---@param bufnr? integer
---@return vim.lsp.Client?
local function jdtls_client(bufnr)
  bufnr = bufnr
    or api.nvim_get_current_buf()

  local clients =
    lsp.get_clients({
      bufnr = bufnr,
    })

  for _, client in ipairs(clients) do
    if is_jdtls(client) then
      return client
    end
  end

  local root =
    project_root(bufnr)

  clients =
    lsp.get_clients()

  for _, client in ipairs(clients) do
    if is_jdtls(client) then
      local client_root =
        client.root_dir

      if
        nonempty_string(client_root)
        and fs.normalize(
          client_root
        ) == root
      then
        return client
      end
    end
  end

  return nil
end

---@param client vim.lsp.Client
---@param command string
---@return boolean
local function supports_command(
  client,
  command
)
  local capabilities =
    client.server_capabilities

  if type(capabilities) ~= "table" then
    return false
  end

  local provider =
    capabilities.executeCommandProvider

  if type(provider) ~= "table" then
    return false
  end

  local commands =
    provider.commands

  if type(commands) ~= "table" then
    return false
  end

  for _, candidate in ipairs(commands) do
    if candidate == command then
      return true
    end
  end

  return false
end

---@return boolean
local function java_debug_loaded()
  local client =
    jdtls_client()

  if client == nil then
    return false
  end

  return supports_command(
    client,
    DEBUG_SESSION_COMMAND
  )
end

---@return string?
local function resolve_java_home()
  if
    state.java_home ~= nil
    and state.java_home ~= ""
  then
    return state.java_home
  end

  local configured =
    vim.env.NVIM_JAVA_HOME
      or vim.env.JAVA_HOME

  if nonempty_string(configured) then
    local root =
      normalize(
        fn.expand(configured)
      )

    local java =
      fs.joinpath(
        root,
        "bin",
        "java"
      )

    if executable(java) then
      state.java_home = root

      return root
    end
  end

  local java =
    executable_path("java")

  if java == nil then
    return nil
  end

  local bin =
    fs.dirname(java)

  if bin == nil then
    return nil
  end

  local root =
    fs.dirname(bin)

  if root == nil then
    return nil
  end

  state.java_home =
    fs.normalize(root)

  return state.java_home
end

---@return string?
local function resolve_java()
  if
    state.java ~= nil
    and executable(state.java)
  then
    return state.java
  end

  local configured =
    vim.env.NVIM_JAVA_EXECUTABLE

  if nonempty_string(configured) then
    local candidate =
      normalize(
        fn.expand(configured)
      )

    if executable(candidate) then
      state.java = candidate

      return candidate
    end

    notify(
      (
        "NVIM_JAVA_EXECUTABLE is not executable: %s"
      ):format(candidate),
      levels.WARN
    )
  end

  local java_home =
    resolve_java_home()

  if java_home ~= nil then
    local candidate =
      fs.joinpath(
        java_home,
        "bin",
        "java"
      )

    if executable(candidate) then
      state.java =
        fs.normalize(candidate)

      return state.java
    end
  end

  local candidate =
    executable_path("java")

  if candidate ~= nil then
    state.java = candidate

    return candidate
  end

  return nil
end

---@param command string[]
---@param cwd? string
---@return vim.SystemCompleted?
local function system(
  command,
  cwd
)
  local ok, result =
    pcall(function()
      return vim.system(
        command,
        {
          cwd = cwd,

          text = true,
        }
      ):wait()
    end)

  if not ok then
    return nil
  end

  return result
end

---@return string?
local function java_version()
  local java =
    resolve_java()

  if java == nil then
    return nil
  end

  local result =
    system({
      java,

      "-version",
    })

  if
    result == nil
    or result.code ~= 0
  then
    return nil
  end

  local output =
    vim.trim(
      result.stderr or ""
    )

  if output == "" then
    output =
      vim.trim(
        result.stdout or ""
      )
  end

  if output == "" then
    return nil
  end

  return output:match(
    "[^\r\n]+"
  )
end

---@return string?
local function requested_java_version()
  local root =
    project_root()

  local java_version_file =
    fs.joinpath(
      root,
      ".java-version"
    )

  if is_file(java_version_file) then
    local lines =
      fn.readfile(
        java_version_file,
        "",
        1
      )

    if nonempty_string(lines[1]) then
      return vim.trim(lines[1])
    end
  end

  local tool_versions =
    fs.joinpath(
      root,
      ".tool-versions"
    )

  if is_file(tool_versions) then
    local lines =
      fn.readfile(tool_versions)

    for _, line in ipairs(lines) do
      local version =
        line:match(
          "^java%s+(%S+)"
        )

      if version ~= nil then
        return version
      end
    end
  end

  return nil
end

---@param result unknown
---@return integer?
local function debug_port(result)
  if type(result) == "number" then
    local port =
      math.floor(result)

    if
      port >= 1
      and port <= 65535
    then
      return port
    end
  end

  if type(result) == "string" then
    local port =
      tonumber(result)

    if
      port ~= nil
      and port >= 1
      and port <= 65535
    then
      return math.floor(port)
    end
  end

  if type(result) == "table" then
    local value =
      result.port
        or result.debugPort

    local port =
      tonumber(value)

    if
      port ~= nil
      and port >= 1
      and port <= 65535
    then
      return math.floor(port)
    end
  end

  return nil
end

---@return JavaDapEndpoint?
local function start_debug_server()
  local bufnr =
    api.nvim_get_current_buf()

  local client =
    jdtls_client(bufnr)

  if client == nil then
    notify(
      table.concat({
        "Eclipse JDT LS is not attached.",

        "",

        "Java debugging requires the java-debug bundle",
        "inside the active JDTLS instance.",
      }, "\n"),
      levels.ERROR
    )

    return nil
  end

  if
    not supports_command(
      client,
      DEBUG_SESSION_COMMAND
    )
  then
    notify(
      table.concat({
        "JDTLS does not expose vscode.java.startDebugSession.",

        "",

        "The Microsoft java-debug JAR is probably not loaded",
        "in JDTLS initializationOptions.bundles.",
      }, "\n"),
      levels.ERROR
    )

    return nil
  end

  local response =
    client:request_sync(
      "workspace/executeCommand",
      {
        command =
          DEBUG_SESSION_COMMAND,

        arguments = {},
      },
      DEBUG_SESSION_TIMEOUT_MS,
      bufnr
    )

  if response == nil then
    notify(
      "JDTLS did not respond while starting the Java debug server",
      levels.ERROR
    )

    return nil
  end

  if response.err ~= nil then
    notify(
      (
        "Java debug server startup failed: %s"
      ):format(
        vim.inspect(
          response.err
        )
      ),
      levels.ERROR
    )

    return nil
  end

  local port =
    debug_port(
      response.result
    )

  if port == nil then
    notify(
      (
        "JDTLS returned an invalid Java DAP port: %s"
      ):format(
        vim.inspect(
          response.result
        )
      ),
      levels.ERROR
    )

    return nil
  end

  local endpoint = {
    host = "127.0.0.1",

    port = port,
  }

  state.endpoint =
    endpoint

  return endpoint
end

---@return integer
local function adapter_port()
  --
  -- Microsoft java-debug creates a new ephemeral DAP listener each time
  -- vscode.java.startDebugSession is requested.
  --
  state.endpoint = nil

  local endpoint =
    start_debug_server()

  if endpoint == nil then
    return 0
  end

  return endpoint.port
end

---@return string
local function cwd()
  local root =
    project_root()

  state.root = root

  return root
end

---@return string
local function current_file()
  local current =
    filename()

  if current ~= "" then
    return current
  end

  return "${file}"
end

---@return string
local function prompt_main_class()
  return fn.input(
    "Java main class: "
  )
end

---@return string
local function prompt_project_name()
  return fn.input(
    "JDTLS project name (blank = auto): "
  )
end

---@return string[]
local function prompt_args()
  local input =
    fn.input(
      "Program arguments: "
    )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string[]
local function prompt_vm_args()
  local input =
    fn.input(
      "JVM arguments: "
    )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return string[]
local function prompt_debug_vm_args()
  local input =
    fn.input(
      "JVM arguments: ",
      "-ea -XX:+ShowCodeDetailsInExceptionMessages"
    )

  if input == "" then
    return {}
  end

  return fn.shellsplit(input)
end

---@return table<string, string>
local function prompt_environment()
  local input =
    fn.input(
      "Environment KEY=VALUE pairs: "
    )

  if input == "" then
    return {}
  end

  ---@type table<string, string>
  local result = {}

  for _, item in ipairs(
    fn.shellsplit(input)
  ) do
    local key, value =
      item:match(
        "^([%a_][%w_]*)=(.*)$"
      )

    if key ~= nil then
      result[key] = value
    else
      notify(
        (
          "ignoring invalid environment assignment: %s"
        ):format(item),
        levels.WARN
      )
    end
  end

  return result
end

---@return string
local function prompt_jdwp_host()
  local host =
    fn.input(
      "JDWP host: ",
      DEFAULT_JDWP_HOST
    )

  if host == "" then
    return DEFAULT_JDWP_HOST
  end

  return host
end

---@return integer
local function prompt_jdwp_port()
  local input =
    fn.input(
      "JDWP port: ",
      tostring(
        DEFAULT_JDWP_PORT
      )
    )

  local port =
    tonumber(input)

  if
    port == nil
    or port < 1
    or port > 65535
  then
    notify(
      (
        "invalid JDWP port: %s"
      ):format(input),
      levels.ERROR
    )

    return DEFAULT_JDWP_PORT
  end

  return math.floor(port)
end

---@return integer
local function prompt_pid()
  local input =
    fn.input(
      "Java process PID: "
    )

  local pid =
    tonumber(input)

  if
    pid == nil
    or pid < 1
  then
    notify(
      (
        "invalid PID: %s"
      ):format(input),
      levels.ERROR
    )

    return 0
  end

  return math.floor(pid)
end

---@return table[]
local function java_processes()
  local result =
    system({
      "ps",

      "-eo",

      "pid=,comm=,args=",
    })

  if
    result == nil
    or result.code ~= 0
  then
    return {}
  end

  ---@type table[]
  local processes = {}

  for line in (
    result.stdout or ""
  ):gmatch("[^\r\n]+") do
    local pid,
      command,
      arguments =
      line:match(
        "^%s*(%d+)%s+(%S+)%s*(.*)$"
      )

    if
      pid ~= nil
      and command ~= nil
    then
      local executable_name =
        command:lower()

      local args =
        (arguments or ""):lower()

      if
        executable_name == "java"
        or executable_name == "javaw"
        or args:find(
          "/java ",
          1,
          true
        ) ~= nil
      then
        processes[#processes + 1] = {
          pid = tonumber(pid),

          command = command,

          arguments =
            arguments or "",
        }
      end
    end
  end

  return processes
end

local function show_java_processes()
  local processes =
    java_processes()

  if #processes == 0 then
    notify(
      "no Java processes found",
      levels.WARN
    )

    return
  end

  local lines = {}

  for _, process in ipairs(
    processes
  ) do
    lines[#lines + 1] =
      (
        "PID %-7d %s %s"
      ):format(
        process.pid,
        process.command,
        process.arguments
      )
  end

  notify(
    table.concat(
      lines,
      "\n"
    )
  )
end

---@return string[]
local function optimized_step_filters()
  return vim.deepcopy(
    STEP_SKIP_CLASSES
  )
end

---@return table
local function step_filters()
  return {
    skipClasses =
      optimized_step_filters(),

    skipSynthetics = true,

    skipStaticInitializers =
      true,

    skipConstructors =
      false,
  }
end

---@return string[]
local function auto_class_paths()
  return {
    "$Auto",
  }
end

---@return string[]
local function runtime_class_paths()
  return {
    "$Runtime",
  }
end

---@return string[]
local function test_class_paths()
  return {
    "$Test",
  }
end

---@return string[]
local function auto_module_paths()
  return {
    "$Auto",
  }
end

---@return string[]
local function runtime_module_paths()
  return {
    "$Runtime",
  }
end

---@return string[]
local function test_module_paths()
  return {
    "$Test",
  }
end

---@return string
local function java_exec()
  return resolve_java()
    or "java"
end

---@return string
local function nonempty_project_name()
  local value =
    prompt_project_name()

  return value
end

local function select_java()
  local selected =
    fn.input(
      "Java executable: ",
      resolve_java() or "",
      "file"
    )

  if selected == "" then
    return
  end

  selected =
    normalize(
      fn.expand(selected)
    )

  if not executable(selected) then
    notify(
      (
        "not executable: %s"
      ):format(selected),
      levels.ERROR
    )

    return
  end

  state.java = selected

  local bin =
    fs.dirname(selected)

  if bin ~= nil then
    state.java_home =
      fs.dirname(bin)
  end

  notify(
    (
      "Java executable: %s"
    ):format(selected)
  )
end

local function clear_cache()
  state.endpoint = nil

  state.java = nil

  state.java_home = nil

  state.root = nil

  notify(
    "Java DAP discovery cache cleared"
  )
end

local function status()
  local client =
    jdtls_client()

  local debug_loaded =
    client ~= nil
      and supports_command(
        client,
        DEBUG_SESSION_COMMAND
      )

  notify(
    table.concat({
      "root: "
        .. project_root(),

      "JDTLS: "
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

      "java-debug bundle: "
        .. (
          debug_loaded
              and "loaded"
            or "not detected"
        ),

      "Java: "
        .. (
          resolve_java()
            or "not found"
        ),

      "JAVA_HOME: "
        .. (
          resolve_java_home()
            or "not found"
        ),

      "Java version: "
        .. (
          java_version()
            or "unknown"
        ),

      "project Java version: "
        .. (
          requested_java_version()
            or "not specified"
        ),

      "DAP broker command: "
        .. DEBUG_SESSION_COMMAND,

      "last DAP endpoint: "
        .. (
          state.endpoint ~= nil
              and (
                "%s:%d"
              ):format(
                state.endpoint.host,
                state.endpoint.port
              )
            or "none"
        ),
    }, "\n"),
    debug_loaded
        and levels.INFO
      or levels.WARN
  )
end

--
-- java-debug is not launched as a standalone executable here.
--
-- Its Eclipse plug-in is loaded into JDTLS. For each debug session Neovim
-- asks JDTLS to execute:
--
--   vscode.java.startDebugSession
--
-- The command returns an ephemeral TCP port exposing Microsoft's Java DAP
-- server.
--
---@type table
M.adapter = {
  name = "java",

  type = "server",

  host = "127.0.0.1",

  port = adapter_port,

  options = {
    source_filetype = "java",
  },
}

---@type table[]
local configurations = {
  --
  -- The java-debug server can resolve `${file}` directly through JDTLS.
  --
  {
    name = "Java: Current File / Main Class",

    type = "java",

    request = "launch",

    mainClass = current_file,

    cwd = cwd,

    javaExec = java_exec,

    classPaths =
      auto_class_paths,

    modulePaths =
      auto_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  {
    name = "Java: Current File with Arguments",

    type = "java",

    request = "launch",

    mainClass = current_file,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs = prompt_vm_args,

    env = prompt_environment,

    classPaths =
      auto_class_paths,

    modulePaths =
      auto_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  {
    name = "Java: Current File (Debug JVM Preset)",

    type = "java",

    request = "launch",

    mainClass = current_file,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs =
      prompt_debug_vm_args,

    env = prompt_environment,

    classPaths =
      auto_class_paths,

    modulePaths =
      auto_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  --
  -- Fully qualified main class is useful for large Maven/Gradle workspaces,
  -- multi-module repositories and Java modules.
  --
  {
    name = "Java: Main Class",

    type = "java",

    request = "launch",

    mainClass =
      prompt_main_class,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs = prompt_vm_args,

    env = prompt_environment,

    classPaths =
      auto_class_paths,

    modulePaths =
      auto_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  {
    name = "Java: Main Class + Project",

    type = "java",

    request = "launch",

    mainClass =
      prompt_main_class,

    projectName =
      nonempty_project_name,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs = prompt_vm_args,

    env = prompt_environment,

    classPaths =
      auto_class_paths,

    modulePaths =
      auto_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  --
  -- Runtime-only classpath/module-path reduces accidental visibility of test
  -- dependencies when debugging production entry points.
  --
  {
    name = "Java: Main Class (Runtime Classpath)",

    type = "java",

    request = "launch",

    mainClass =
      prompt_main_class,

    projectName =
      nonempty_project_name,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs = prompt_vm_args,

    env = prompt_environment,

    classPaths =
      runtime_class_paths,

    modulePaths =
      runtime_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  --
  -- Useful for custom test launchers and frameworks whose main entry point is
  -- supplied manually. Full JUnit/TestNG Test Explorer integration requires
  -- Microsoft's separate java-test JDTLS bundle.
  --
  {
    name = "Java: Main Class (Test Classpath)",

    type = "java",

    request = "launch",

    mainClass =
      prompt_main_class,

    projectName =
      nonempty_project_name,

    cwd = cwd,

    javaExec = java_exec,

    args = prompt_args,

    vmArgs = prompt_debug_vm_args,

    env = prompt_environment,

    classPaths =
      test_class_paths,

    modulePaths =
      test_module_paths,

    console =
      "integratedTerminal",

    encoding = "UTF-8",

    shortenCommandLine =
      "auto",

    stepFilters =
      step_filters,
  },

  --
  -- Standard JDWP attach.
  --
  -- A local process can be started with:
  --
  --   java \
  --     -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=127.0.0.1:5005 \
  --     ...
  --
  {
    name = "Java: Attach localhost:5005",

    type = "java",

    request = "attach",

    hostName =
      DEFAULT_JDWP_HOST,

    port =
      DEFAULT_JDWP_PORT,

    stepFilters =
      step_filters,
  },

  {
    name = "Java: Attach JDWP",

    type = "java",

    request = "attach",

    hostName =
      prompt_jdwp_host,

    port =
      prompt_jdwp_port,

    stepFilters =
      step_filters,
  },
}

---@type table<string, table[]>
M.configurations = {
  java = configurations,
}

---@type table<string, DebugCommand>
M.commands = {
  JavaDebugClear = {
    callback = function()
      clear_cache()
    end,

    desc =
      "Clear Java DAP discovery cache",
  },

  JavaDebugJava = {
    callback = function()
      select_java()
    end,

    desc =
      "Select Java executable",
  },

  JavaDebugProcesses = {
    callback = function()
      show_java_processes()
    end,

    desc =
      "Show running Java processes",
  },

  JavaDebugServer = {
    callback = function()
      local endpoint =
        start_debug_server()

      if endpoint ~= nil then
        notify(
          (
            "Java DAP server: %s:%d"
          ):format(
            endpoint.host,
            endpoint.port
          )
        )
      end
    end,

    desc =
      "Start Java DAP server through JDTLS",
  },

  JavaDebugStatus = {
    callback = function()
      status()
    end,

    desc =
      "Show Java debugger status",
  },
}

---@type table<string, DebugMapping>
M.mappings = {
  java_debug_java = {
    lhs = "<leader>dJj",

    mode = "n",

    rhs = function()
      select_java()
    end,

    desc =
      "Debug Java: Select JDK",
  },

  java_debug_processes = {
    lhs = "<leader>dJp",

    mode = "n",

    rhs = function()
      show_java_processes()
    end,

    desc =
      "Debug Java: Processes",
  },

  java_debug_server = {
    lhs = "<leader>dJd",

    mode = "n",

    rhs = function()
      local endpoint =
        start_debug_server()

      if endpoint ~= nil then
        notify(
          (
            "Java DAP server: %s:%d"
          ):format(
            endpoint.host,
            endpoint.port
          )
        )
      end
    end,

    desc =
      "Debug Java: Start DAP server",
  },

  java_debug_status = {
    lhs = "<leader>dJs",

    mode = "n",

    rhs = function()
      status()
    end,

    desc =
      "Debug Java: Status",
  },
}

---@param opts? table
function M.setup(opts)
  opts = opts or {}

  state.root =
    nonempty_string(opts.root)
        and fs.normalize(opts.root)
      or project_root()

  if resolve_java() == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Java runtime was not found.",

          "",

          "Set one of:",

          "  NVIM_JAVA_EXECUTABLE=/path/to/java",

          "  NVIM_JAVA_HOME=/path/to/jdk",

          "  JAVA_HOME=/path/to/jdk",
        }, "\n"),
        levels.ERROR
      )
    end)
  end

  local client =
    jdtls_client()

  if client == nil then
    vim.schedule(function()
      notify(
        table.concat({
          "Eclipse JDT LS is not currently attached.",

          "",

          "Java DAP definitions were registered, but debugging",
          "requires the JDTLS client for this workspace.",
        }, "\n"),
        levels.DEBUG
      )
    end)

    return
  end

  if
    not supports_command(
      client,
      DEBUG_SESSION_COMMAND
    )
  then
    vim.schedule(function()
      notify(
        table.concat({
          "Microsoft java-debug was not detected in JDTLS.",

          "",

          "Add the built java-debug plugin JAR to:",

          "  initializationOptions.bundles",

          "",

          "Expected command after loading:",

          "  vscode.java.startDebugSession",
        }, "\n"),
        levels.WARN
      )
    end)
  end
end

---@return string?
function M.java()
  return resolve_java()
end

---@return string?
function M.java_home()
  return resolve_java_home()
end

---@return string
function M.root()
  return project_root()
end

---@return vim.lsp.Client?
function M.jdtls()
  return jdtls_client()
end

---@return boolean
function M.available()
  return resolve_java() ~= nil
    and java_debug_loaded()
end

---@return JavaDapEndpoint?
function M.endpoint()
  return state.endpoint
end

return M