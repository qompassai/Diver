-- /qompassai/diver/after/syntax/md.lua
-- Qompass AI Diver After Syntax for Markdown
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@return string
local function html_unescape(s) ---@param s string
  s = s:gsub('&amp;', '&')
  s = s:gsub('&lt;', '<')
  s = s:gsub('&gt;', '>')
  s = s:gsub('&quot;', '"')
  s = s:gsub('&#39;', '\'')
  return s
end
---@param s any
---@return boolean
local function is_url(s)
  return type(s) == 'string' and s:match('^https?://')
end
---@return string|nil
local function parse_title(html) ---@param html string|nil
  if not html or html == '' then
    return nil
  end
  local h = html:gsub('\r\n', '\n')
  ---@param pattern string
  ---@return string|nil
  local function meta_content(pattern)
    local content = h:match(pattern)
    if content then
      content = vim.trim(html_unescape(content))
      if content ~= '' then
        return content
      end
    end
    return nil
  end
  local og = meta_content('<meta[^>]-property=["\']og:title["\'][^>]-content=["\'](.-)["\'][^>]->')
      or meta_content('<meta[^>]-content=["\'](.-)["\'][^>]-property=["\']og:title["\'][^>]->')
  if og then
    return og
  end
  local tw = meta_content('<meta[^>]-name=["\']twitter:title["\'][^>]-content=["\'](.-)["\'][^>]->')
      or meta_content('<meta[^>]-content=["\'](.-)["\'][^>]-name=["\']twitter:title["\'][^>]->')
  if tw then
    return tw
  end
  local t = h:match('<title[^>]*>(.-)</title>')
  if t then
    t = vim.trim(html_unescape(t:gsub('%s+', ' ')))
    if t ~= '' then
      return t
    end
  end
  return nil
end
---@param url string
---@return string
local function fallback_title_from_url(url)
  local host = url:match('^https?://([^/%?#]+)') or url
  local last = url:match('^https?://[^/]+/(.-)$')
  if last and last ~= '' then
    last = last:gsub('[?#].*$', '') ---@type string
    last = last:gsub('/+$', '')
    local seg = last:match('([^/]+)$')
    if seg and seg ~= '' then
      seg = seg:gsub('[-_]+', ' ') ---@type string
      return seg
    end
  end
  return host
end
---@class VimSystemResult
---@field code integer
---@field stdout string|nil
---@field stderr string|nil
---@param url string
---@return string|nil html
---@return string|nil err
local function fetch_html(url)
  local cmd = {
    'curl',
    '-fsSL',
    '--compressed',
    '-m',
    '15',
    url,
  }
  local out = vim.system(cmd, ---@type vim.SystemCompleted
    {
      text = true
    }):wait()
  if out.code ~= 0 then
    return nil, ('curl failed (%d): %s'):format(out.code, vim.trim(out.stderr or ''))
  end
  return out.stdout, nil
end
---@alias TitleCallback fun(title: string)
---@param url string
---@param callback TitleCallback
---@return string|nil
local function handle_link(url, callback)
  local html, err = fetch_html(url)
  if err then
    local title = fallback_title_from_url(url)
    callback(title)
    vim.notify(
      'Inserted link (fallback title). Fetch failed: ' .. err,
      vim.log.levels.WARN
    )
    return nil
  end
  local title = parse_title(html) or fallback_title_from_url(url)
  title = title:gsub('%]', '\\]')
  callback(title)
  return title
end
---@alias PastePhase -1|1|2
---@alias PasteHandler fun(lines: string[], phase: PastePhase): boolean?
---@type PasteHandler
vim.paste = (function(overridden)
  ---@param lines string[]
  ---@param phase PastePhase
  ---@return boolean?
  return function(lines, phase)
    if vim.bo.filetype == 'markdown' then
      if #lines == 1 and is_url(lines[1]) then
        local url = lines[1]
        local title = handle_link(url, function(_) end) or url
        local link = ('[%s](%s)'):format(title, url)
        return overridden({ link }, phase)
      end
    end
    return overridden(lines, phase)
  end
end)(vim.paste)