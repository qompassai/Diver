-- /qompassai/Diver/lua/utils/docs/latex.lua
-- Qompass AI Diver LaTeX Authoring Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param path string
---@return string
local function root(path)
  local markers = { '.latexmkrc', 'latexmkrc', 'main.tex', '.git' }
  local found = vim.fs.find(markers, {
    path = fs.dirname(path),
    upward = true,
    limit = 1,
  })
  return found[1] and fs.dirname(found[1]) or fs.dirname(path)
end

---@param path? string
---@return string?
function M.current(path)
  path = path or api.nvim_buf_get_name(0)
  return path ~= '' and fs.normalize(path) or nil
end

---@param path string
---@param callback? fun(result: vim.SystemCompleted)
function M.compile(path, callback)
  local cwd = root(path)
  local command
  if fn.executable('latexmk') == 1 then
    command = {
      'latexmk',
      '-pdf',
      '-interaction=nonstopmode',
      '-synctex=1',
      '-file-line-error',
      path,
    }
  elseif fn.executable('tectonic') == 1 then
    command = { 'tectonic', '--synctex', '--keep-logs', path }
  else
    vim.notify('Neither latexmk nor tectonic is executable', vim.log.levels.ERROR)
    return
  end
  vim.system(command, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify('LaTeX build complete', vim.log.levels.INFO)
      else
        vim.notify(vim.trim(result.stderr or result.stdout or 'LaTeX build failed'), vim.log.levels.ERROR)
      end
      if callback then
        callback(result)
      end
    end)
  end)
end

---@param path string
function M.clean(path)
  if fn.executable('latexmk') ~= 1 then
    vim.notify('latexmk is not executable', vim.log.levels.WARN)
    return
  end
  vim.system({ 'latexmk', '-c', path }, {
    cwd = root(path),
    text = true,
  })
end

---@param path string
---@param callback fun(count: integer?, output?: string)
function M.word_count(path, callback)
  if fn.executable('texcount') ~= 1 then
    callback(nil, 'texcount is not executable')
    return
  end
  vim.system({ 'texcount', '-sum', '-1', path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, vim.trim(result.stderr or 'texcount failed'))
        return
      end
      callback(tonumber(vim.trim(result.stdout or '')), result.stdout)
    end)
  end)
end

---@param path string
---@param callback? fun(result: vim.SystemCompleted)
function M.lint(path, callback)
  local cmd
  if fn.executable('chktex') == 1 then
    cmd = { 'chktex', '-q', '-f', '%f:%l:%c:%d:%k:%n:%m\n', path }
  elseif fn.executable('lacheck') == 1 then
    cmd = { 'lacheck', path }
  else
    vim.notify('Neither chktex nor lacheck is executable', vim.log.levels.WARN)
    return
  end
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.stdout and result.stdout ~= '' then
        local items = {}
        for line in result.stdout:gmatch('[^\r\n]+') do
          local file, lnum, col, typ, nr, msg = line:match('^([^:]+):(%d+):(%d+):([^:]+):([^:]+):%d+:(.*)$')
          if file then
            items[#items + 1] = {
              filename = file,
              lnum = tonumber(lnum),
              col = tonumber(col),
              type = typ == 'Warning' and 'W' or 'I',
              nr = tonumber(nr),
              text = msg,
            }
          else
            items[#items + 1] = { filename = path, lnum = 1, text = line, type = 'W' }
          end
        end
        fn.setqflist({}, ' ', { title = 'LaTeX lint', items = items })
        vim.cmd.copen()
      end
      if callback then
        callback(result)
      end
    end)
  end)
end

function M.setup()
  api.nvim_create_user_command('LatexBuild', function(opts)
    local path = opts.args ~= '' and opts.args or M.current()
    if path then
      M.compile(path)
    end
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Build LaTeX with latexmk or tectonic',
  })

  api.nvim_create_user_command('LatexClean', function()
    local path = M.current()
    if path then
      M.clean(path)
    end
  end, { desc = 'Clean LaTeX build artifacts' })

  api.nvim_create_user_command('LatexWords', function()
    local path = M.current()
    if path then
      M.word_count(path, function(count, err)
        if count then
          vim.notify(('TeX word count: %d'):format(count), vim.log.levels.INFO)
        else
          vim.notify(err or 'Word count failed', vim.log.levels.ERROR)
        end
      end)
    end
  end, { desc = 'Count manuscript words with texcount' })

  api.nvim_create_user_command('LatexLint', function()
    local path = M.current()
    if path then
      M.lint(path)
    end
  end, { desc = 'Lint current LaTeX manuscript' })
end

return M