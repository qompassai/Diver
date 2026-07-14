-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Doc Utils Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local bo = vim.bo
local b = vim.b
local v = vim.v
local notify = vim.notify
local inspect = vim.inspect
local decode = vim.json.decode
local split = vim.split
local treesitter = vim.treesitter
local levels = vim.log.levels
local map = vim.keymap.set
---@param bufnr integer?
---@return integer
local function current_buf(bufnr)
  return bufnr or api.nvim_get_current_buf()
end
---@param bufnr integer?
---@return string
local function filetype(bufnr)
  local buf = current_buf(bufnr)
  return bo[buf] and bo[buf].filetype or ''
end
---@return string
function M.foldexpr()
  local buf = api.nvim_get_current_buf()
  if b[buf].ts_folds == nil then
    local ft = filetype(buf)
    if ft == '' then
      return '0'
    end
    if ft:find('dashboard', 1, true) then
      b[buf].ts_folds = false
    else
      b[buf].ts_folds = pcall(treesitter.get_parser, buf)
    end
  end
  return b[buf].ts_folds and treesitter.foldexpr() or '0'
end
---@return string
function M.foldtext()
  local lines = api.nvim_buf_get_lines(0, v.lnum - 1, v.lnum, false)
  return lines[1] or ''
end

local function json_to_lua()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local json = table.concat(lines, '\n')
  json = json:gsub('//[^\n]*', '')
  json = json:gsub('/%*.-%*/', '')
  json = json:gsub(',(%s*[}%]])', '%1')

  local ok, result = pcall(decode, json)
  if not ok then
    notify('Failed to parse JSON: ' .. tostring(result), levels.ERROR)
    return
  end
  cmd('vnew')
  api.nvim_buf_set_lines(0, 0, -1, false, split(inspect(result), '\n'))
  bo[0].filetype = 'lua'
end
local function jsonc_to_lua()
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local jsonc = table.concat(lines, '\n')

  jsonc = jsonc:gsub('//[^\n]*\n', '\n')
  jsonc = jsonc:gsub('/%*.-%*/', '')
  jsonc = jsonc:gsub(',(%s*[}%]])', '%1')

  local ok, result = pcall(decode, jsonc)
  if not ok then
    notify('JSON parse error: ' .. tostring(result), levels.ERROR)
    cmd('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, split(jsonc, '\n'))
    bo[0].filetype = 'json'
    return
  end
  cmd('vnew')
  api.nvim_buf_set_lines(0, 0, -1, false, split('return ' .. inspect(result), '\n'))
  bo[0].filetype = 'lua'
  notify('Converted to Lua', levels.INFO)
end
--[[
---@param infile string
local function markdown_pdf(infile)
  if infile == '' then
    notify('No markdown file to convert', levels.ERROR)
    return
  end
  local outfile = infile:gsub('%.%w+$', '') .. '.pdf'
  local args = {
    'pandoc',
    infile,
    '--from=markdown+yaml_metadata_block+implicit_figures+link_attributes',
    '--pdf-engine=xelatex',
    '--toc',
    '--metadata',
    'link-citations=true',
    '-o',
    outfile,
  }
  fn.jobstart(args, {
    on_exit = function(_, code)
      if code == 0 then
        notify('PDF written to ' .. outfile, levels.INFO)
      else
        notify('Pandoc failed for ' .. infile, levels.ERROR)
      end
    end,
  })
end
--]]
function M.setup()
  local group = api.nvim_create_augroup('docs', {
    clear = true,
  })

  api.nvim_create_autocmd('CmdlineChanged', {
    group = group,
    pattern = {
      ':',
      '/',
      '?',
    },
    callback = function()
      fn.wildtrigger()
    end,
  })

  api.nvim_create_autocmd({
    'FocusGained',
    'BufEnter',
    'CursorHold',
    'CursorHoldI',
  }, {
    group = group,
    callback = function(args)
      if not args or not args.buf then
        return
      end

      local ft = filetype(args.buf)
      if ft ~= '' and ft ~= 'vim' and fn.mode() ~= 'c' then
        cmd('checktime')
      end
    end,
  })
  api.nvim_create_user_command('Align', function(opts)
    local buf = api.nvim_get_current_buf()
    for lnum = opts.line1, opts.line2 do
      local lines = api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)
      local line = lines[1] or ''
      local annotation, description = line:match('^(%s*%-%-%-@%S+%s+%S+)%s+(.*)$')
      if annotation and description then
        api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, {
          string.format('%-58s %s', annotation, description),
        })
      end
    end
  end, {
    range = true,
    desc = 'Align Lua annotation descriptions',
  })
  api.nvim_create_user_command('Json2Lua', json_to_lua, {
    desc = 'Convert current JSON buffer to Lua',
  })
  api.nvim_create_user_command('JsonC2Lua', jsonc_to_lua, {
    desc = 'Convert current JSONC buffer to Lua',
  })
  --[[
  api.nvim_create_user_command('MarkdownPdf', function(opts)
    local infile = opts.args ~= '' and opts.args or api.nvim_buf_get_name(0)
    markdown_pdf(infile)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Convert current markdown file or given file to PDF',
  })
  --]]
  map('n', '<leader>cj', json_to_lua, {
    desc = 'Convert JSON to Lua',
    silent = true,
  })
  map('n', '<leader>cJ', jsonc_to_lua, {
    desc = 'Convert JSONC to Lua',
    silent = true,
  })
  --[[
  map('n', '<leader>cp', function()
    markdown_pdf(api.nvim_buf_get_name(0))
  end, {
    desc = 'Convert Markdown to PDF',
    silent = true,
  })
  --]]
end

return M