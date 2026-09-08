ib.lua
-- /qompassai/Diver/lua/utils/docs/bib.lua
-- Qompass AI Diver Bibliography Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local M = {}

---@param line string
---@return string?
function M.key(line)
  return line:match('^%s*@[%w]+%s*{%s*([^,%s]+)')
end

---@param bufnr? integer
---@return table<string, integer[]>
function M.keys(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local out = {}
  for lnum, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local key = M.key(line)
    if key then
      out[key] = out[key] or {}
      out[key][#out[key] + 1] = lnum
    end
  end
  return out
end

---@param bufnr? integer
---@return vim.quickfix.entry[]
function M.duplicates(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local items = {}
  for key, lines in pairs(M.keys(bufnr)) do
    if #lines > 1 then
      for _, lnum in ipairs(lines) do
        items[#items + 1] = {
          bufnr = bufnr,
          lnum = lnum,
          col = 1,
          type = 'W',
          text = ('Duplicate BibTeX key: %s'):format(key),
        }
      end
    end
  end
  table.sort(items, function(a, b)
    return a.lnum < b.lnum
  end)
  return items
end

---@param path string
function M.check(path)
  if fn.executable('biber') == 1 then
    vim.system({ 'biber', '--tool', '--validate-datamodel', path }, { text = true }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          vim.notify('Bibliography validation completed', vim.log.levels.INFO)
        else
          vim.notify(vim.trim(result.stderr or result.stdout or 'biber validation failed'), vim.log.levels.WARN)
        end
      end)
    end)
    return
  end
  if fn.executable('bibtool') == 1 then
    vim.system({ 'bibtool', '-r', 'check.rsc', path }, { text = true })
    return
  end
  vim.notify('Neither biber nor bibtool is executable', vim.log.levels.WARN)
end

function M.setup()
  api.nvim_create_user_command('BibDuplicates', function()
    local items = M.duplicates()
    fn.setqflist({}, ' ', {
      title = 'Duplicate bibliography keys',
      items = items,
    })
    if #items > 0 then
      vim.cmd.copen()
    else
      vim.notify('No duplicate BibTeX keys found', vim.log.levels.INFO)
    end
  end, { desc = 'Find duplicate BibTeX keys' })

  api.nvim_create_user_command('BibCheck', function(opts)
    local path = opts.args ~= '' and opts.args or api.nvim_buf_get_name(0)
    if path ~= '' then
      M.check(path)
    end
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Validate bibliography with biber or bibtool',
  })
end

return M