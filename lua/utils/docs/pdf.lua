-- /qompassai/Diver/lua/utils/docs/pdf.lua
-- Qompass AI Diver PDF Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local fn = vim.fn
local fs = vim.fs
local M = {}

---@param cmd string[]
---@param opts? vim.SystemOpts
---@param callback? fun(result: vim.SystemCompleted)
local function run(cmd, opts, callback)
  opts = vim.tbl_extend('force', { text = true }, opts or {})
  if callback then
    vim.system(cmd, opts, function(result)
      vim.schedule(function()
        callback(result)
      end)
    end)
    return
  end
  return vim.system(cmd, opts)
end

---@param path? string
---@return string?
function M.current(path)
  path = path or api.nvim_buf_get_name(0)
  if path == '' then
    return nil
  end
  return fs.normalize(path)
end

---@param path string
---@param callback fun(info: table?, error?: string)
function M.info(path, callback)
  if fn.executable('pdfinfo') ~= 1 then
    callback(nil, 'pdfinfo is not executable')
    return
  end
  run({ 'pdfinfo', path }, {}, function(result)
    if result.code ~= 0 then
      callback(nil, vim.trim(result.stderr or 'pdfinfo failed'))
      return
    end
    local info = {}
    for line in (result.stdout or ''):gmatch('[^\r\n]+') do
      local key, value = line:match('^([^:]+):%s*(.*)$')
      if key and value then
        info[vim.trim(key)] = vim.trim(value)
      end
    end
    callback(info)
  end)
end

---@param path string
---@param opts? { layout?: boolean, first_page?: integer, last_page?: integer }
---@param callback fun(text: string?, error?: string)
function M.text(path, opts, callback)
  opts = opts or {}
  if fn.executable('pdftotext') ~= 1 then
    callback(nil, 'pdftotext is not executable')
    return
  end
  local cmd = { 'pdftotext' }
  if opts.layout ~= false then
    cmd[#cmd + 1] = '-layout'
  end
  if opts.first_page then
    vim.list_extend(cmd, { '-f', tostring(opts.first_page) })
  end
  if opts.last_page then
    vim.list_extend(cmd, { '-l', tostring(opts.last_page) })
  end
  vim.list_extend(cmd, { path, '-' })
  run(cmd, {}, function(result)
    if result.code ~= 0 then
      callback(nil, vim.trim(result.stderr or 'pdftotext failed'))
      return
    end
    callback(result.stdout or '')
  end)
end

---@param path string
---@param opts? { layout?: boolean, first_page?: integer, last_page?: integer, output?: string }
---@param callback? fun(ok: boolean, output?: string, error?: string)
function M.extract(path, opts, callback)
  opts = opts or {}
  local output = opts.output or path:gsub('%.pdf$', '') .. '.txt'
  M.text(path, opts, function(text, err)
    if not text then
      if callback then
        callback(false, nil, err)
      end
      return
    end
    fn.writefile(vim.split(text, '\n', { plain = true }), output)
    if callback then
      callback(true, output)
    end
  end)
end

---@param path string
---@param page integer
function M.open_page(path, page)
  page = math.max(1, page)
  if fn.executable('zathura') == 1 then
    vim.system({ 'zathura', '--page', tostring(page), path }, { detach = true })
    return
  end
  if fn.executable('okular') == 1 then
    vim.system({ 'okular', ('%s#page=%d'):format(path, page) }, { detach = true })
    return
  end
  if fn.executable('xdg-open') == 1 then
    vim.system({ 'xdg-open', path }, { detach = true })
    return
  end
  vim.notify('No supported PDF viewer found', vim.log.levels.WARN)
end

---@param path string
---@param callback? fun(ok: boolean, output?: string, error?: string)
function M.review_text(path, callback)
  local output = path:gsub('%.pdf$', '') .. '.review.txt'
  M.extract(path, { layout = true, output = output }, callback)
end

function M.setup()
  api.nvim_create_user_command('PdfInfo', function(opts)
    local path = opts.args ~= '' and opts.args or M.current()
    if not path then
      return
    end
    M.info(path, function(info, err)
      if not info then
        vim.notify(err or 'Unable to read PDF metadata', vim.log.levels.ERROR)
        return
      end
      vim.notify(vim.inspect(info), vim.log.levels.INFO)
    end)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Show PDF metadata',
  })

  api.nvim_create_user_command('PdfText', function(opts)
    local path = opts.args ~= '' and opts.args or M.current()
    if not path then
      return
    end
    M.review_text(path, function(ok, output, err)
      if not ok then
        vim.notify(err or 'PDF extraction failed', vim.log.levels.ERROR)
        return
      end
      vim.cmd.edit(fn.fnameescape(output))
    end)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Extract layout-preserving PDF text for review',
  })

  api.nvim_create_user_command('PdfPage', function(opts)
    local path = M.current()
    if path and path:match('%.pdf$') then
      M.open_page(path, tonumber(opts.args) or 1)
    end
  end, {
    nargs = 1,
    desc = 'Open current PDF at page',
  })
end

return M