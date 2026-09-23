-- /qompassai/Diver/lua/config/ui/image.lua
-- Qompass AI Diver Native Image Preview
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Uses Neovim's experimental vim.ui.img API directly. No image.nvim,
-- ImageMagick, Tree-sitter HTML integration, downloader, or shell command.
-- Neovim currently supports PNG through its Kitty graphics implementation.

local api = vim.api
local fn = vim.fn

local M = {}

local defaults = {
  enabled = false,
  height = 16,
  margin = 2,
  row = 2,
  width = 42,
  zindex = 60,
}

local config = vim.deepcopy(defaults)
local state = {
  enabled = false,
  generation = 0,
  id = nil,
  source = nil,
}

local png_magic = '\137PNG\r\n\26\n'

---@param value any
---@return boolean
local function positive_integer(value)
  return type(value) == 'number' and value == math.floor(value) and value > 0
end

---@param message string
local function notify(message)
  vim.notify(message, vim.log.levels.WARN, { title = 'Native image preview' })
end

---@return boolean
local function available()
  return type(vim.ui) == 'table'
    and type(vim.ui.img) == 'table'
    and type(vim.ui.img.set) == 'function'
    and type(vim.ui.img.del) == 'function'
end

---@param options table?
local function validate(options)
  if options == nil then
    return
  end
  assert(type(options) == 'table', 'image options must be a table')

  if options.enabled ~= nil then
    assert(type(options.enabled) == 'boolean', 'image.enabled must be a boolean')
  end
  for _, key in ipairs({ 'height', 'margin', 'row', 'width', 'zindex' }) do
    if options[key] ~= nil then
      assert(positive_integer(options[key]), 'image.' .. key .. ' must be a positive integer')
    end
  end
end

local function clear_current()
  state.generation = state.generation + 1

  local id = state.id
  state.id = nil
  state.source = nil

  if id ~= nil and available() then
    pcall(vim.ui.img.del, id)
  end
end

---@param source string
---@return string?
local function local_path(source)
  if source:match('^https?://') then
    return nil
  end

  source = source:gsub('^<', ''):gsub('>$', '')
  if source == '' then
    return nil
  end

  if source:match('^~') then
    source = fn.expand(source)
  elseif not source:match('^/') and not source:match('^%a:[/\\]') then
    local buffer_name = api.nvim_buf_get_name(0)
    if buffer_name ~= '' then
      source = vim.fs.joinpath(fn.fnamemodify(buffer_name, ':h'), source)
    end
  end

  return vim.fs.normalize(source)
end

---@return string?
local function image_buffer_path()
  local name = api.nvim_buf_get_name(0)
  if name:lower():match('%.png$') then
    return name
  end
  return nil
end

---@return string?
local function markdown_image_path()
  local filetype = vim.bo.filetype
  if filetype ~= 'markdown' and filetype ~= 'markdown.mdx' then
    return nil
  end

  local line = api.nvim_get_current_line()
  local target = line:match('!%[[^%]]*%]%((.-)%)')
  if not target then
    return nil
  end

  target = vim.trim(target)
  target = target:match('^<([^>]+)>') or target:match('^([^%s]+)')
  if not target or not target:lower():match('%.png$') then
    return nil
  end

  return local_path(target)
end

---@param path string
---@return string? blob
---@return string? error_message
local function read_png(path)
  if path:lower():match('%.png$') == nil then
    return nil, 'vim.ui.img currently supports PNG only: ' .. path
  end
  if fn.filereadable(path) ~= 1 then
    return nil, 'image is not readable: ' .. path
  end

  local ok, blob = pcall(fn.readblob, path)
  if not ok or type(blob) ~= 'string' then
    return nil, 'could not read image: ' .. path
  end
  if blob:sub(1, #png_magic) ~= png_magic then
    return nil, 'file is not a PNG image: ' .. path
  end

  return blob, nil
end

---@return table
local function image_options()
  local columns = vim.o.columns
  local width = math.min(config.width, math.max(1, columns - (config.margin * 2)))

  return {
    col = math.max(1, columns - width - config.margin + 1),
    height = config.height,
    row = config.row,
    width = width,
    zindex = config.zindex,
  }
end

---@param path string
---@param silent boolean?
---@return boolean
local function display(path, silent)
  if not state.enabled then
    return false
  end
  if not available() then
    if not silent then
      notify('vim.ui.img is unavailable; use a Neovim build with native image support and Kitty graphics support')
    end
    return false
  end

  local blob, read_error = read_png(path)
  if not blob then
    if not silent then
      notify(read_error or 'unable to load image')
    end
    return false
  end

  if state.source == path and state.id ~= nil then
    return true
  end

  clear_current()
  local ok, id = pcall(vim.ui.img.set, blob, image_options())
  if not ok or type(id) ~= 'number' then
    if not silent then
      notify('vim.ui.img.set failed: ' .. tostring(id))
    end
    return false
  end

  state.id = id
  state.source = path
  return true
end

---@param path string?
function M.render(path)
  if path ~= nil then
    local resolved = local_path(path)
    if not resolved then
      notify('remote image URLs are not supported by the native preview')
      return
    end
    display(resolved)
    return
  end

  M.refresh()
end

function M.refresh()
  if not state.enabled then
    return
  end

  local path = image_buffer_path() or markdown_image_path()
  if path then
    display(path, true)
  else
    clear_current()
  end
end

function M.clear()
  clear_current()
end

function M.toggle()
  state.enabled = not state.enabled
  if state.enabled then
    M.refresh()
  else
    clear_current()
  end
end

function M.setup(options)
  validate(options)
  config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), options or {})
  state.enabled = config.enabled

  api.nvim_create_user_command('ImagePreviewToggle', M.toggle, {
    desc = 'Toggle native PNG image preview',
    force = true,
  })
  api.nvim_create_user_command('ImagePreviewRefresh', M.refresh, {
    desc = 'Refresh native PNG image preview',
    force = true,
  })
  api.nvim_create_user_command('ImagePreviewClear', M.clear, {
    desc = 'Clear native PNG image preview',
    force = true,
  })

  local group = api.nvim_create_augroup('NativeImagePreview', { clear = true })
  api.nvim_create_autocmd({ 'BufEnter', 'CursorMoved', 'VimResized', 'WinEnter' }, {
    group = group,
    callback = M.refresh,
    desc = 'Refresh native PNG image preview',
  })
  api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'BufWipeout' }, {
    group = group,
    callback = M.clear,
    desc = 'Clear native PNG image preview',
  })

  if state.enabled then
    M.refresh()
  end
end

return M
