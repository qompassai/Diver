-- /qompassai/Diver/lua/config/autocmds.lua
-- Qompass AI Diver Doc Utils Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT
local autocmd = vim.api.nvim_create_autocmd
local b = vim.b
local bo = vim.bo
local buf = vim.api.nvim_get_current_buf()
local bufgl = vim.api.nvim_buf_get_lines
local bufsl = vim.api.nvim_buf_set_lines
local cmd = vim.cmd
local concat = table.concat
local decode = vim.json.decode
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local inspect = vim.inspect
local ft = vim.bo.filetype
local fn = vim.fn
local notify = vim.notify
local split = vim.split
local tree = vim.treesitter
local usercmd = vim.api.nvim_create_user_command
local v = vim.v
function M.foldexpr()
  if b[buf].ts_folds == nil then
    if bo[buf].filetype == '' then
      return '0'
    end
    if bo[buf].filetype:find('dashboard') then
      b[buf].ts_folds = false
    else
      b[buf].ts_folds = pcall(tree.get_parser, buf)
    end
  end
  return b[buf].ts_folds and tree.foldexpr() or '0'
end

function M.foldtext()
  return bufgl(0, v.lnum - 1, v.lnum, false)[1]
end

---@return string
local function get_relative_path(filepath) ---@param filepath string
  local qompass_idx = filepath:find('/qompassai/')
  if qompass_idx then
    return filepath:sub(qompass_idx + 1)
  else
    local rel = fn.fnamemodify(filepath, ':~:.')
    return rel
  end
end
usercmd('Align', function(opts)
  local start_line = opts.line1
  local end_line = opts.line2
  for lnum = start_line, end_line do
    local line = bufgl(0, lnum - 1, lnum, false)[1]
    local annotation, description = line:match('^(%s*%-%-%-@%S+%s+%S+)%s+(.*)$')
    if annotation and description then
      local aligned = string.format('%-58s %s', annotation, description)
      bufsl(0, lnum - 1, lnum, false, {
        aligned,
      })
    end
  end
end, {
  range = true,
})
function M.make_header( ---@return string[]
    filepath, ---@param filepath string
    comment ---@param comment string
)
  local relpath = get_relative_path(filepath)
  local rep = string.rep
  local description = 'Qompass AI - [ ]'
  local copyright = 'Copyright (C) 2026 Qompass AI, All rights reserved'
  local solid ---@type string
  if comment == '<!--' then
    solid = '<!-- ' .. rep('-', 40) .. ' -->'
    return {
      '<!-- ' .. relpath .. ' -->',
      '<!-- ' .. description .. ' -->',
      '<!-- ' .. copyright .. ' -->',
      solid,
    }
  elseif comment == '/*' then
    solid = '/* ' .. rep('-', 40) .. ' */'
    return {
      '/* ' .. relpath .. ' */',
      '/* ' .. description .. ' */',
      '/* ' .. copyright .. ' */',
      solid,
    }
  else
    solid = comment .. ' ' .. rep('-', 40)
    return {
      comment .. ' ' .. relpath,
      comment .. ' ' .. description,
      comment .. ' ' .. copyright,
      solid,
    }
  end
end

autocmd('CmdlineChanged', {
  pattern = {
    ':',
    '/',
    '?',
  },
  callback = function()
    fn.wildtrigger()
  end,
})
autocmd({
  'FocusGained',
  'BufEnter',
  'CursorHold',
  'CursorHoldI',
}, {
  callback = function()
    if ft ~= '' and ft ~= 'vim' and fn.mode() ~= 'c' then
      cmd('checktime')
    end
  end,
})
usercmd('Json2Lua', function()
  local lines = bufgl(0, 0, -1, false)
  local json_str = concat(lines, '\n')
  json_str = json_str:gsub('//[^\n]*', '')
  json_str = json_str:gsub('/%*.-%*/', '')
  json_str = json_str:gsub(',(%s*[}%]])', '%1')
  local ok, lua_table = pcall(decode, json_str)
  if not ok then
    notify('Failed to parse JSON: ' .. lua_table, ERROR)
    return
  end
  local lua_str = inspect(lua_table)
  cmd('vnew')
  bufsl(0, 0, -1, false, split(lua_str, '\n'))
  ft = 'lua'
end, {})
usercmd('JsonC2Lua', function()
  local lines = bufgl(0, 0, -1, false)
  local content = concat(lines, '\n')
  content = content:gsub('//[^\n]*\n', '\n')
  content = content:gsub('/%*.--%*/', '')
  content = content:gsub(',(%s*[}%]])', '%1')
  local ok, result = pcall(decode, content)
  if not ok then
    notify('JSON parse error: ' .. result, ERROR)
    cmd('vnew')
    bufsl(0, 0, -1, false, split(content, '\n'))
    ft = 'json'
    return
  end
  local lua_str = 'return ' .. inspect(result)
  cmd('vnew')
  bufsl(0, 0, -1, false, split(lua_str, '\n'))
  ft = 'lua'
  notify('Converted to Lua', INFO)
end, {})
autocmd('BufWritePost', {
  pattern = {
    '*.md',
    '*.markdown',
  },
  callback = function(args)
    local infile = args.file
    local outfile = infile:gsub('%.%w+$', '') .. '.pdf'
    local pdoc = {
      'pandoc',
      infile,
      '--from=markdown+yaml_metadata_block+implicit_figures+link_attributes',
      '--pdf-engine=xelatex',
      -- '--pdf-engine=lualatex'
      '--toc',
      '--metadata',
      'link-citations=true',
      '-o',
      outfile,
    }
    fn.jobstart(pdoc, {
      on_exit = function(_, code)
        if code ~= 0 then
          notify('Pandoc failed for ' .. infile, ERROR)
        else
          notify('PDF written to ' .. outfile, INFO)
        end
      end,
    })
  end,
})
return M