-- /qompassai/Diver/lua/utils/docs/mime.lua
-- Qompass AI Diver Doc Mime Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {} ---@version JIT
local autocmd = vim.api.nvim_create_autocmd
local insert = table.insert
local mime_file = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')) .. '/nvim/lua/utils/docs/mime.lua'
local function collect_mime_extensions()
  local function split(str, sep)
    if not str then
      return {}
    end
    local fields = {}
    local pattern = string.format('([^%s]+)', sep)
    str:gsub(pattern, function(c)
      fields[#fields + 1] = c
    end)
    return fields
  end
  local function getenv_or_default(name, default)
    local v = vim.env[name]
    if v == nil or v == '' then
      return default
    end
    return v
  end
  local function path_join(a, b)
    if a:sub(-1) == '/' then
      return a .. b
    else
      return a .. '/' .. b
    end
  end
  local function find_globs2_files()
    local files = {}
    local home = vim.env.HOME or ''
    local xdg_data_home = getenv_or_default('XDG_DATA_HOME', home ~= '' and (home .. '/.local/share') or nil)
    if xdg_data_home then
      insert(files, path_join(xdg_data_home, 'mime/globs2'))
    end
    local xdg_data_dirs = getenv_or_default('XDG_DATA_DIRS', '/usr/local/share:/usr/share')
    for _, dir in ipairs(split(xdg_data_dirs, ':')) do
      insert(files, path_join(dir, 'mime/globs2'))
    end
    return files
  end
  local function parse_globs2(path, mime_to_exts)
    local file = io.open(path, 'r')
    if not file then
      return
    end
    for line in file:lines() do
      if line:sub(1, 1) ~= '#' and line:match('%S') then
        local _, mtype, glob = line:match('^([^:]+):([^:]+):([^:]+)') ---:TODO
        if mtype and glob and glob ~= '__NOGLOBS__' then
          local ext = glob:match('^%*%.([^%*]+)$')
          if ext and ext ~= '' then
            local exts = mime_to_exts[mtype]
            if not exts then
              exts = {}
              mime_to_exts[mtype] = exts
            end
            local seen = false
            for _, e in ipairs(exts) do
              if e == ext then
                seen = true
                break
              end
            end
            if not seen then
              insert(exts, ext)
            end
          end
        end
      end
    end
    file:close()
  end
  local mime_to_exts = {}
  for _, path in ipairs(find_globs2_files()) do
    parse_globs2(path, mime_to_exts)
  end
  for _, exts in pairs(mime_to_exts) do
    table.sort(exts)
  end
  return mime_to_exts
end
function M.update()
  local mime_to_exts = collect_mime_extensions()
  local mtypes = {}
  for mtype, _ in pairs(mime_to_exts) do
    table.insert(mtypes, mtype)
  end
  table.sort(mtypes)
  local lines = {}
  insert(lines, 'local M = {}')
  insert(lines, '')
  insert(lines, 'M.mime_types_ = {')
  for _, mtype in ipairs(mtypes) do
    local exts = mime_to_exts[mtype]
    if #exts == 1 then
      insert(lines, string.format('  ["%s"] = "%s",', mtype, exts[1]))
    else
      local parts = {}
      for i, ext in ipairs(exts) do
        parts[#parts + 1] = string.format(' [%d] = "%s"', i, ext)
      end
      insert(lines, string.format('  ["%s"] = {%s },', mtype, table.concat(parts, ',')))
    end
  end
  insert(lines, '}')
  insert(lines, '')
  insert(lines, 'return M')
  local f = assert(io.open(mime_file, 'w'))
  f:write(table.concat(lines, '\n'))
  f:close()
end

M.mime_types_ = M.mime_types_ or {}
local group = vim.api.nvim_create_augroup('MimeAutoUpdate', { clear = true })
autocmd('VimEnter', {
  group = group,
  callback = function()
    local ok, mime = pcall(require, 'utils.mime')
    if not ok then
      return
    end
    vim.schedule(function()
      pcall(mime.update)
    end)
  end,
})
return M