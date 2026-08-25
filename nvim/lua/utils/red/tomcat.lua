-- /qompassai/Diver/lua/utils/red/tomcat.lua
-- Qompass AI Diver RedTeam TomCat Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local function shell_escape(s)
  return s:gsub([=[']=], [['"']])
end
local function run_curl(args, opts, cb)
  opts = opts or {}
  local cmd = { 'curl', '--silent', '--show-error', '--location', '--max-redirs', '3' }
  vim.list_extend(cmd, {
    '--connect-timeout',
    tostring(opts.connect_timeout or 3),
    '--max-time',
    tostring(opts.max_time or 8),
  })
  if opts.head then
    table.insert(cmd, '--head')
  end
  vim.list_extend(cmd, {
    '--dump-header',
    '-',
    '--write-out',
    '\n__STATUS__:%{http_code}\n',
  })
  if opts.userpwd then
    table.insert(cmd, '--user')
    table.insert(cmd, shell_escape(opts.userpwd))
  end
  if opts.http11 then
    table.insert(cmd, '--http1.1')
  end
  if opts.insecure then
    table.insert(cmd, '--insecure')
  end
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(res)
    if res.code ~= 0 then
      cb(nil, string.format('curl failed (code=%d): %s', res.code, (res.stderr or ''):gsub('%s+$', '')))
      return
    end
    cb(res.stdout or '', nil)
  end)
end
local function parse_headers_and_status(raw)
  local status = raw:match('__STATUS__:(%d+)')
  status = status and tonumber(status) or nil
  local headers = {}
  for line in raw:gmatch('[^\r\n]+') do
    if line:match('^HTTP/') then
      headers._status_line = line
    else
      local k, v = line:match('^([%w%-]+):%s*(.*)$')
      if k and v then
        headers[k:lower()] = v
      end
    end
  end
  return status, headers
end
local function url_for(host, port, path, scheme)
  scheme = scheme or 'http'
  path = path or '/manager/html'
  if not path:match('^/') then
    path = '/' .. path
  end
  return string.format('%s://%s:%d%s', scheme, host, port, path)
end
function M.check(opts, on_done)
  opts = opts or {}
  local host = assert(opts.host, 'opts.host required')
  local port = tonumber(opts.port) or 8080
  local path = opts.path or '/manager/html'
  local scheme = opts.scheme or 'http'
  local url = url_for(host, port, path, scheme)
  run_curl({ url }, {
    head = true,
    http11 = true,
    insecure = opts.insecure,
    connect_timeout = 3,
    max_time = 8,
  }, function(stdout, err)
    if err then
      on_done({ ok = false, error = err, url = url })
      return
    end
    local status, headers = parse_headers_and_status(stdout)
    if not status then
      on_done({ ok = false, error = 'Could not parse HTTP status', url = url, raw = stdout })
      return
    end
    local auth = headers['www-authenticate'] or ''
    local server = headers['server']
    local loc = headers['location']
    local result = {
      ok = true,
      url = url,
      status = status,
      protected = (status == 401 and auth:lower():find('basic', 1, true) ~= nil) and true or false,
      auth_header = auth ~= '' and auth or nil,
      server = server,
      redirected_to = loc,
      notes = {},
    }
    if status >= 200 and status < 400 and not result.protected then
      table.insert(result.notes, 'Endpoint did not respond with 401+Basic; verify access controls.')
    end
    if server then
      table.insert(result.notes, 'Server header present (fingerprinting). Consider suppressing it at the proxy.')
    end
    if loc and loc:match('^http://') and scheme == 'https' then
      table.insert(result.notes, 'Redirect downgraded to http:// (possible misconfig).')
    end
    if opts.verify_cred and opts.verify_cred.user and opts.verify_cred.pass then
      local userpwd = opts.verify_cred.user .. ':' .. opts.verify_cred.pass
      run_curl({ url }, {
        head = true,
        http11 = true,
        insecure = opts.insecure,
        userpwd = userpwd,
        connect_timeout = 3,
        max_time = 8,
      }, function(stdout2, err2)
        if err2 then
          result.cred_check = { ok = false, error = err2 }
          on_done(result)
          return
        end
        local status2, _ = parse_headers_and_status(stdout2)
        result.cred_check = {
          ok = (status2 == 200),
          status = status2,
        }
        on_done(result)
      end)
      return
    end
    on_done(result)
  end)
end

function M.pretty_print(r)
  local lines = {}
  table.insert(lines, ('Tomcat Manager check: %s'):format(r.url or '?'))
  if not r.ok then
    table.insert(lines, ('  ERROR: %s'):format(r.error or 'unknown'))
    return table.concat(lines, '\n')
  end
  table.insert(lines, ('  HTTP status: %s'):format(r.status or '?'))
  table.insert(lines, ('  Basic Auth protected: %s'):format(r.protected and 'yes' or 'no'))
  if r.auth_header then
    table.insert(lines, ('  WWW-Authenticate: %s'):format(r.auth_header))
  end
  if r.server then
    table.insert(lines, ('  Server: %s'):format(r.server))
  end
  if r.redirected_to then
    table.insert(lines, ('  Redirected to: %s'):format(r.redirected_to))
  end
  if r.cred_check then
    table.insert(
      lines,
      ('  Credential check: %s (status=%s)'):format(
        r.cred_check.ok and 'VALID' or 'invalid',
        r.cred_check.status or '?'
      )
    )
  end
  if r.notes and #r.notes > 0 then
    table.insert(lines, '  Notes:')
    for _, n in ipairs(r.notes) do
      table.insert(lines, ('    - %s'):format(n))
    end
  end
  return table.concat(lines, '\n')
end

return M