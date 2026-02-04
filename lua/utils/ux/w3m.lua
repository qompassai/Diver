-- /qompassai/Diver/lua/utils/w3m.lua
-- Qompass AI Diver UX W3M Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
------------------------------------------------------
local M = {}
local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify
local ucmd = api.nvim_create_user_command
M.OPEN_NORMAL = 0
M.OPEN_SPLIT = 1
M.OPEN_TAB = 2
M.OPEN_VSPLIT = 3
M.config = {
  command = 'w3m',
  download_ext = {
    'cab',
    'exe',
    'zip',
    'lzh',
    'tar',
    'gz',
    'z',
  },
  external_browser = 'chrome',
  hit_a_hint_key = 'f',
  hover_delay_time = 100,
  lang = vim.v.lang,
  max_cache_page_num = 10,
  max_history_num = 30,
  option_accept_bad_cookie = -1,
  option_accept_cookie = -1,
  option_use_cookie = -1,
  page_filter_list = {},
  search_engine_list = {},
  set_hover_on = true,
  user_agent = '',
  wget_command = 'wget',
}
M.user_agents = {
  {
    name = 'w3m',
    agent = '',
  },
  {
    name = 'Chrome',
    agent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  },
  {
    name = 'Firefox',
    agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0',
  },
  {
    name = 'Safari',
    agent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15',
  },
  {
    name = 'Edge',
    agent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  },
  {
    name = 'Android',
    agent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.200 Mobile Safari/537.36',
  },
  {
    name = 'iOS',
    agent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1',
  },
}
local function build_options()
  return string.format(
    '-o display_charset=%s -halfdump -o frame=true -o ext_halfdump=1 -o strict_iso2022=0 -o ucs_conv=1',
    vim.o.encoding
  )
end
local function get_search_engine()
  if M.config.lang == 'ja_JP' or M.config.lang == 'ja' then
    return string.format('https://search.yahoo.co.jp/search?p=%%s&ei=%s', vim.o.encoding)
  else
    return string.format('https://www.google.com/search?q=%%s&ie=%s', vim.o.encoding)
  end
end
---@param opts? table User configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  if fn.executable(M.config.command) == 0 then
    notify('w3m is not installed or not in PATH!', levels.ERROR)
    return false
  end
  M.create_commands()
  return true
end

---Open URL in w3m
---@param mode number Open mode (NORMAL, SPLIT, TAB, VSPLIT)
---@param ... any URL or search terms
function M.open(mode, ...)
  local args = { ... }
  if #args == 0 then
    notify('No URL or search terms provided', levels.WARN)
    return
  end
  local url = args[1]
  if not url:match('^https?://') and not url:match('^file://') then
    url = string.format(get_search_engine(), fn.escape(url, ' '))
  end
  if mode == M.OPEN_SPLIT then
    cmd('split')
  elseif mode == M.OPEN_VSPLIT then
    cmd('vsplit')
  elseif mode == M.OPEN_TAB then
    cmd('tabnew')
  end
  local buf = vim.api.nvim_create_buf(false, true)
  api.nvim_set_current_buf(buf)
  local wcmd = string.format('%s %s "%s"', M.config.command, build_options(), url)
  if M.config.debug then
    notify('Running: ' .. cmd, levels.DEBUG)
  end
  fn.jobstart(wcmd, {
    term = true,
    on_exit = function(_, code)
      if code ~= 0 and M.config.debug then
        notify('w3m exited with code: ' .. code, levels.WARN)
      end
    end,
  })
  bo[buf].buftype = 'nofile'
  bo[buf].bufhidden = 'wipe'
  bo[buf].swapfile = false
  bo[buf].filetype = 'w3m'
end

---Open local file in w3m
---@param path string File path
function M.open_local(path)
  local full_path = fn.fnamemodify(path, ':p')
  if fn.filereadable(full_path) == 0 then
    notify('File not found: ' .. path, levels.ERROR)
    return
  end
  M.open(M.OPEN_NORMAL, 'file://' .. full_path)
end

---@return table List
function M.list_user_agents()
  local names = {}
  for _, ua in ipairs(M.user_agents) do
    table.insert(names, ua.name)
  end
  return names
end

---@param name string
function M.set_user_agent(name)
  for _, ua in ipairs(M.user_agents) do
    if ua.name == name then
      M.config.user_agent = ua.agent
      notify('User agent set to: ' .. name, levels.INFO)
      return true
    end
  end
  notify('User agent not found: ' .. name, levels.WARN)
  return false
end

function M.create_commands()
  ucmd('W3m', function(opts)
    M.open(M.OPEN_NORMAL, unpack(opts.fargs))
  end, {
    nargs = '*',
    desc = 'Open URL in w3m browser',
  })
  ucmd('W3mTab', function(opts)
    M.open(M.OPEN_TAB, unpack(opts.fargs))
  end, {
    nargs = '*',
    desc = 'Open URL in w3m browser (new tab)',
  })

  ucmd('W3mSplit', function(opts)
    M.open(M.OPEN_SPLIT, unpack(opts.fargs))
  end, {
    nargs = '*',
    desc = 'Open URL in w3m browser (split)',
  })
  ucmd('W3mVSplit', function(opts)
    M.open(M.OPEN_VSPLIT, unpack(opts.fargs))
  end, {
    nargs = '*',
    desc = 'Open URL in w3m browser (vertical split)',
  })
  ucmd('W3mLocal', function(opts)
    if #opts.fargs == 0 then
      notify('No file path provided', levels.WARN)
      return
    end
    M.open_local(opts.fargs[1])
  end, {
    nargs = 1,
    complete = 'file',
    desc = 'Open local file in w3m browser',
  })
  ucmd('W3mUserAgent', function(opts)
    if #opts.fargs == 0 then
      local agents = M.list_user_agents()
      notify('Available user agents:\n  ' .. table.concat(agents, '\n  '), levels.INFO)
    else
      M.set_user_agent(opts.fargs[1])
    end
  end, {
    nargs = '?',
    complete = function()
      return M.list_user_agents()
    end,
    desc = 'Set or list user agents',
  })
end

return M