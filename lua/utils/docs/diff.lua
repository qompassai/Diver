-- /qompassai/Diver/lua/utils/docs/diff.lua
-- Qompass AI Diver Manuscript Diff Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param old_path string
---@param new_path string
---@param output? string
function M.latex(old_path, new_path, output)
  if fn.executable('latexdiff') ~= 1 then
    vim.notify('latexdiff is not executable', vim.log.levels.ERROR)
    return
  end
  output = output or fs.joinpath(fs.dirname(new_path), 'diff-' .. fs.basename(new_path))
  vim.system({ 'latexdiff', old_path, new_path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(vim.trim(result.stderr or 'latexdiff failed'), vim.log.levels.ERROR)
        return
      end
      fn.writefile(vim.split(result.stdout or '', '\n', { plain = true }), output)
      vim.notify('LaTeX diff written to ' .. output, vim.log.levels.INFO)
    end)
  end)
end

---@param old_path string
---@param new_path string
function M.word(old_path, new_path)
  local cmd
  if fn.executable('git') == 1 then
    cmd = { 'git', 'diff', '--no-index', '--word-diff=plain', '--', old_path, new_path }
  elseif fn.executable('diff') == 1 then
    cmd = { 'diff', '-u', old_path, new_path }
  else
    vim.notify('Neither git nor diff is executable', vim.log.levels.ERROR)
    return
  end
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result.stdout or '', '\n', { plain = true }))
      vim.bo[buf].buftype = 'nofile'
      vim.bo[buf].bufhidden = 'wipe'
      vim.bo[buf].swapfile = false
      vim.cmd.vnew()
      api.nvim_win_set_buf(0, buf)
      vim.bo[buf].filetype = 'diff'
    end)
  end)
end

function M.setup()
  api.nvim_create_user_command('ManuscriptDiff', function(opts)
    local args = vim.split(opts.args, '%s+', { trimempty = true })
    if #args ~= 2 then
      vim.notify('Usage: ManuscriptDiff {old} {new}', vim.log.levels.ERROR)
      return
    end
    M.word(args[1], args[2])
  end, {
    nargs = '+',
    complete = 'file',
    desc = 'Show word-level manuscript diff',
  })

  api.nvim_create_user_command('LatexDiff', function(opts)
    local args = vim.split(opts.args, '%s+', { trimempty = true })
    if #args ~= 2 then
      vim.notify('Usage: LatexDiff {old.tex} {new.tex}', vim.log.levels.ERROR)
      return
    end
    M.latex(args[1], args[2])
  end, {
    nargs = '+',
    complete = 'file',
    desc = 'Create latexdiff manuscript',
  })
end

return M