local M = {
  _logfile = vim.fn.tempname() .. "_perplexity.log",
  _max_log_lines = 10000,
  _debug_enabled = vim.env.DEBUG_PERPLEXITY ~= nil,
}

local notify_ok, notify = pcall(require, "notify")
if notify_ok then
  vim.notify = notify
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return ""
  end
  local content = file:read "*a"
  file:close()
  return content
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end

local function limit_logfile_lines()
  local content = read_file(M._logfile)
  local lines = vim.split(content, "\n")
  if #lines > M._max_log_lines then
    table.remove(lines, 1)
  end
  return table.concat(lines, "\n")
end

local function write_to_logfile(msg, kind)
  local limited_log = limit_logfile_lines()
  local new_log_entry = string.format("[%s] %s: %s\n", os.date "%Y-%m-%d %H:%M:%S", kind, msg)
  write_file(M._logfile, limited_log .. new_log_entry)
end

local function log(msg, kind, level, notify_user)
  notify_user = notify_user or false  -- Default to false

  write_to_logfile(msg, kind)

  if notify_user and kind ~= "Debug" then
    vim.schedule(function()
      vim.notify(msg, level, { title = kind })
    end)
  end
end

function M.error(msg, notify_user)
  log(msg, "ErrorMsg", vim.log.levels.ERROR, notify_user)
end

function M.warning(msg, notify_user)
  log(msg, "WarningMsg", vim.log.levels.WARN, notify_user)
end

function M.info(msg, notify_user)
  log(msg, "Normal", vim.log.levels.INFO, notify_user)
end

function M.debug(msg, notify_user)
  if M._debug_enabled then
    log(msg, "Debug", vim.log.levels.DEBUG, notify_user)
  end
end

return M

