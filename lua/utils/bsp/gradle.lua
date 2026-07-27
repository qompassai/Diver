-- #################################################################
-- /qompassai/lua/utils/bsp/gradle.lua
-- Qompass AI Gradle BSP
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
local M = {}

local uv = vim.uv or vim.loop

local state = {
  root = nil,
  initialized = false,
  shutting_down = false,
  next_id = 0,
  targets = nil,
  client = nil,
  recv_buf = "",
  pending = {},
}

local function notify(msg, level)
  vim.notify("[BSP] " .. msg, level or vim.log.levels.INFO)
end

local function is_dir(path)
  return vim.fn.isdirectory(path) == 1
end

local function is_file(path)
  return vim.fn.filereadable(path) == 1
end

local function has_java(bin)
  return vim.fn.executable(bin or "java") == 1
end

local function is_gradle_project(root)
  if not root then
    return false
  end
  return is_file(root .. "/settings.gradle")
    or is_file(root .. "/settings.gradle.kts")
    or is_file(root .. "/build.gradle")
    or is_file(root .. "/build.gradle.kts")
end

local function find_root(bufnr)
  return vim.fs.root(bufnr or 0, {
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    ".bsp",
    ".git",
  })
end

local function path_to_uri(path)
  return vim.uri_from_fname(path)
end

local function encode(msg)
  local json = vim.json.encode(msg)
  return ("Content-Length: %d

%s"):format(#json, json)
end

local function next_id()
  state.next_id = state.next_id + 1
  return state.next_id
end

local function on_message(msg)
  if msg.id and state.pending[msg.id] then
    local cb = state.pending[msg.id]
    state.pending[msg.id] = nil
    cb(msg.error, msg.result)
    return
  end

  if msg.method == "build/logMessage" and msg.params then
    notify(msg.params.message or "log", vim.log.levels.INFO)
  elseif msg.method == "build/showMessage" and msg.params then
    local t = msg.params.type
    local level = vim.log.levels.INFO
    if t == 1 then
      level = vim.log.levels.ERROR
    elseif t == 2 then
      level = vim.log.levels.WARN
    end
    notify(msg.params.message or "message", level)
  end
end

local function parse_messages(chunk)
  state.recv_buf = state.recv_buf .. chunk

  while true do
    local header_end = state.recv_buf:find("

", 1, true)
    if not header_end then
      return
    end

    local header = state.recv_buf:sub(1, header_end + 3)
    local len = header:match("Content%-Length:%s*(%d+)")
    len = tonumber(len)
    if not len then
      notify("invalid BSP header", vim.log.levels.ERROR)
      state.recv_buf = ""
      return
    end

    local body_start = header_end + 4
    local body_end = body_start + len - 1
    if #state.recv_buf < body_end then
      return
    end

    local body = state.recv_buf:sub(body_start, body_end)
    state.recv_buf = state.recv_buf:sub(body_end + 1)

    local ok, decoded = pcall(vim.json.decode, body)
    if ok and decoded then
      vim.schedule(function()
        on_message(decoded)
      end)
    end
  end
end

local function send(msg)
  if not state.client or not state.client.stdin then
    return false
  end
  local ok = state.client.stdin:write(encode(msg))
  return ok ~= false
end

local function request(method, params, cb)
  local id = next_id()
  state.pending[id] = cb or function() end
  local ok = send({
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params,
  })
  if not ok then
    state.pending[id] = nil
    return false
  end
  return true
end

local function notify_server(method, params)
  return send({
    jsonrpc = "2.0",
    method = method,
    params = params,
  })
end

local function start_server(config)
  if state.client then
    return true
  end

  local java = config.java_binary or "java"
  local launcher_main = config.launcher_main or "com.microsoft.java.bs.core.Launcher"
  local plugin_dir = config.plugin_dir
  local classpath = config.classpath

  if not has_java(java) then
    notify("java not found in PATH", vim.log.levels.WARN)
    return false
  end

  if not plugin_dir or not is_dir(plugin_dir) then
    notify("plugin_dir is required and must exist", vim.log.levels.ERROR)
    return false
  end

  local cmd = { java, "-Dplugin.dir=" .. plugin_dir, "-DdisableServerTelemetry=true" }

  if classpath and classpath ~= "" then
    vim.list_extend(cmd, { "-cp", classpath, launcher_main })
  else
    table.insert(cmd, launcher_main)
  end

  local stdout = uv.new_pipe(false)
  local stdin = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid
  handle, pid = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { stdin, stdout, stderr },
    cwd = state.root,
  }, function(code, signal)
    vim.schedule(function()
      notify(("server exited code=%s signal=%s"):format(code, signal), vim.log.levels.INFO)
    end)
    if stdout and not stdout:is_closing() then stdout:close() end
    if stdin and not stdin:is_closing() then stdin:close() end
    if stderr and not stderr:is_closing() then stderr:close() end
    if handle and not handle:is_closing() then handle:close() end
    state.client = nil
    state.initialized = false
    state.targets = nil
  end)

  if not handle then
    notify("failed to spawn Gradle BSP server", vim.log.levels.ERROR)
    return false
  end

  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        notify("stdout error: " .. err, vim.log.levels.ERROR)
      end)
      return
    end
    if data then
      parse_messages(data)
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      return
    end
    if data and data ~= "" then
      vim.schedule(function()
        notify(vim.trim(data), vim.log.levels.WARN)
      end)
    end
  end)

  state.client = {
    handle = handle,
    pid = pid,
    stdin = stdin,
    stdout = stdout,
    stderr = stderr,
    cmd = cmd,
  }

  return true
end

local function initialize(config, cb)
  if state.initialized then
    if cb then cb(true) end
    return
  end

  request("build/initialize", {
    displayName = "Neovim",
    version = tostring(vim.version()),
    bspVersion = "2.2.0",
    rootUri = path_to_uri(state.root),
    capabilities = {
      languageIds = { "java", "kotlin", "groovy" },
    },
  }, function(err, result)
    if err then
      notify("build/initialize failed: " .. (err.message or "unknown error"), vim.log.levels.ERROR)
      if cb then cb(false, err) end
      return
    end

    state.initialized = true
    notify_server("build/initialized", {})
    if cb then cb(true, result) end
  end)
end

function M.targets(cb)
  if not state.initialized then
    notify("BSP not initialized", vim.log.levels.WARN)
    return
  end

  request("workspace/buildTargets", {}, function(err, result)
    if err then
      notify("workspace/buildTargets failed", vim.log.levels.ERROR)
      return
    end
    state.targets = result and result.targets or {}
    if cb then
      cb(state.targets)
    else
      local names = {}
      for _, target in ipairs(state.targets) do
        table.insert(names, target.displayName or target.id.uri)
      end
      notify("targets: " .. table.concat(names, ", "))
    end
  end)
end

local function with_targets(fn)
  if state.targets and #state.targets > 0 then
    fn(state.targets)
    return
  end
  M.targets(function(targets)
    if not targets or #targets == 0 then
      notify("no build targets found", vim.log.levels.WARN)
      return
    end
    fn(targets)
  end)
end

function M.compile()
  with_targets(function(targets)
    local ids = vim.tbl_map(function(t) return t.id end, targets)
    request("buildTarget/compile", { targets = ids }, function(err, result)
      if err then
        notify("compile failed", vim.log.levels.ERROR)
        return
      end
      notify("compile finished with status " .. tostring(result and result.statusCode))
    end)
  end)
end

function M.test()
  with_targets(function(targets)
    local ids = vim.tbl_map(function(t) return t.id end, targets)
    request("buildTarget/test", { targets = ids }, function(err, result)
      if err then
        notify("test failed", vim.log.levels.ERROR)
        return
      end
      notify("test finished with status " .. tostring(result and result.statusCode))
    end)
  end)
end

function M.reload()
  if not state.initialized then
    notify("BSP not initialized", vim.log.levels.WARN)
    return
  end
  request("workspace/reload", {}, function(err, _)
    if err then
      notify("reload failed", vim.log.levels.ERROR)
      return
    end
    notify("workspace reloaded")
  end)
end

function M.stop()
  if not state.client then
    return
  end

  if state.shutting_down then
    return
  end
  state.shutting_down = true

  request("build/shutdown", {}, function()
    notify_server("build/exit", {})
    state.shutting_down = false
  end)
end

function M.setup(config)
  config = config or {}

  state.root = find_root(0)
  if not state.root or not is_gradle_project(state.root) then
    return
  end

  if not start_server(config) then
    return
  end

  initialize(config, function(ok)
    if not ok then
      return
    end

    vim.api.nvim_create_user_command("GradleBspTargets", function()
      M.targets()
    end, {})

    vim.api.nvim_create_user_command("GradleBspCompile", function()
      M.compile()
    end, {})

    vim.api.nvim_create_user_command("GradleBspTest", function()
      M.test()
    end, {})

    vim.api.nvim_create_user_command("GradleBspReload", function()
      M.reload()
    end, {})

    vim.api.nvim_create_user_command("GradleBspStop", function()
      M.stop()
    end, {})
  end)

  return true
end

return M
