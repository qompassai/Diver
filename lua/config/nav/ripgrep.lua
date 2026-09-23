-- /qompassai/Diver/lua/config/nav/ripgrep.lua
-- ripgrep JSON -> native quickfix/location lists; no shell command construction.
-- SPDX-License-Identifier: Apache-2.0
local api, fs = vim.api, vim.fs
local async = require('config.core.async')
local qf = require('config.core.qf')
local M = {}
local generation, process = 0, nil
local ITEMS_MAX, RECORDS_MAX = 20000, 100000

local function notify(text)
  vim.notify(text, vim.log.levels.WARN, {
    title = 'Ripgrep',
  })
end

local function decode_text(value)
  if type(value) ~= 'table' then
    return
  end
  if type(value.text) == 'string' then
    return value.text
  end
  if type(value.bytes) == 'string' then
    local ok, text = pcall(vim.base64.decode, value.bytes)
    if ok then
      return text
    end
  end
end

---@return table[]?, string?
function M.parse(output, root)
  assert(type(output) == 'string' and type(root) == 'string')
  if #output > 8 * 1024 * 1024 then
    return nil, 'Output exceeds 8 MiB'
  end
  local items, visited = {}, 0
  for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
    visited = visited + 1
    if visited > RECORDS_MAX then
      return nil, 'Too many ripgrep records'
    end
    local ok, record = pcall(vim.json.decode, line)
    if not ok or type(record) ~= 'table' then
      return nil, 'Malformed ripgrep JSON'
    end
    if record.type == 'match' then
      local data = record.data
      if type(data) ~= 'table' then
        return nil, 'Malformed match'
      end
      local path, text = decode_text(data.path), decode_text(data.lines)
      if
        not path
        or path:find('%z')
        or not text
        or type(data.submatches) ~= 'table'
        or type(data.line_number) ~= 'number'
        or data.line_number < 1
        or data.line_number % 1 ~= 0
      then
        return nil, 'Malformed match location'
      end
      if not path:match('^/') and not path:match('^%a:[/\\]') then
        path = fs.joinpath(root, path)
      end
      for _, match in ipairs(data.submatches) do
        if
          type(match) ~= 'table'
          or type(match.start) ~= 'number'
          or match.start < 0
          or match.start % 1 ~= 0
          or match.start > #text
        then
          return nil, 'Malformed match column'
        end
        if #items == ITEMS_MAX then
          return nil, 'More than 20000 matches; narrow the search'
        end
        items[#items + 1] = {
          filename = path,
          lnum = data.line_number,
          col = match.start + 1,
          text = text:gsub('[\r\n]+$', ''),
        }
      end
    end
  end
  return items
end

function M.cancel()
  generation = generation + 1
  if process then
    local ok, err = pcall(process.kill, process, 9)
    if not ok then
      notify('Cancel: ' .. tostring(err))
    end
    process = nil
  end
end

---@param query? string
---@param opts? {kind?: 'qf'|'loc', fixed?: boolean, word?: boolean, cwd?: string}
function M.search(query, opts)
  opts = opts or {}
  local target = qf.target(opts.kind or 'qf')
  local name = api.nvim_buf_get_name(0)
  local start = name ~= '' and fs.dirname(name) or vim.fn.getcwd()
  local root = opts.cwd
    or fs.root(start, {
      '.git',
      'pyproject.toml',
      'Cargo.toml',
      'go.mod',
      'package.json',
    })
    or vim.fn.getcwd()
  M.cancel()
  local token = generation
  local function run(value)
    if token ~= generation or value == nil or value == '' then
      return
    end
    if type(value) ~= 'string' or #value > 4096 or value:find('%z') then
      notify('Invalid query')
      return
    end
    if vim.fn.executable('rg') ~= 1 then
      notify('Install ripgrep (rg)')
      return
    end
    local argv = {
      'rg',
      '--json',
      '--no-config',
      '--smart-case',
      '--hidden',
      '--glob',
      '!.git',
    }
    if opts.fixed then
      argv[#argv + 1] = '--fixed-strings'
    end
    if opts.word then
      argv[#argv + 1] = '--word-regexp'
    end
    vim.list_extend(argv, { '--', value, '.' })
    local err
    process, err = async.spawn(argv, { cwd = root, timeout = 15000 }, function(result)
      if token ~= generation then
        return
      end
      process = nil
      if result.error or result.signal ~= 0 or (result.code ~= 0 and result.code ~= 1) then
        notify(result.error or result.stderr ~= '' and result.stderr or 'Search failed')
        return
      end
      local items, parse_error = M.parse(result.stdout, root)
      if not items then
        notify(parse_error)
        return
      end
      if not api.nvim_win_is_valid(target.win) then
        notify('Search window closed')
        return
      end
      local what = {
        items = items,
        title = 'rg: ' .. value,
        context = { source = 'ripgrep', cwd = root, query = value },
      }
      local status = target.kind == 'loc' and vim.fn.setloclist(target.win, {}, ' ', what)
        or vim.fn.setqflist({}, ' ', what)
      if status ~= 0 then
        notify('Unable to create results list')
        return
      end
      if api.nvim_get_current_win() == target.win and #items > 0 then
        M.open(target)
      end
      vim.notify(('%d ripgrep matches'):format(#items))
    end)
    if err then
      notify(err)
    end
  end
  if query == nil then
    vim.ui.input({ prompt = 'Ripgrep pattern: ' }, run)
  else
    run(query)
  end
end

function M.open(target)
  api.nvim_win_call(target.win, function()
    qf.open(target.kind)
  end)
end

function M.word()
  M.search(vim.fn.expand('<cword>'), { fixed = true, word = true })
end
return M
