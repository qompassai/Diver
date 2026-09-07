#!/usr/bin/env lua

-- image.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--
-- Image preview for Neovim 0.13+.
--
-- Supported sources:
-- - Image files opened directly in Neovim.
-- - Inline Markdown images: ![alt](path-or-url).
-- - Local paths relative to the Markdown buffer.
-- - HTTPS remote images, with HTTP opt-in.
--
-- Commands:
--   :ImagePreviewToggle
--   :ImagePreviewRefresh
--   :ImagePreviewClear
--
-- Module:
--   require("config.ui.image").setup()

local api = vim.api
local fn = vim.fn
local fs = vim.fs

-- Dynamic Neovim 0.13+ API boundaries.
-- LuaLS metadata for vim.ui.img, vim.net, and vim.uv may be incomplete.
---@type any
local image_api = vim.ui.img

---@type any
local network_api = vim.net

local M = {}

local AUGROUP_NAME = 'QompassImagePreview'

local CACHE_ENTRY_COUNT_MAX_DEFAULT = 32
local DEBOUNCE_MS_DEFAULT = 150
local IMAGE_BYTES_MAX_DEFAULT = 10 * 1024 * 1024
local PENDING_REQUEST_COUNT_MAX_DEFAULT = 1

local PREVIEW_HEIGHT_FRACTION_DEFAULT = 0.70
local PREVIEW_MARGIN_DEFAULT = 2
local PREVIEW_ROW_DEFAULT = 2
local PREVIEW_WIDTH_FRACTION_DEFAULT = 0.32
local PREVIEW_ZINDEX_DEFAULT = 60

---@class ImagePreviewOptions
---@field allow_http boolean?
---@field cache_entry_count_max integer?
---@field debounce_ms integer?
---@field enabled boolean?
---@field image_bytes_max integer?
---@field markdown_filetypes table<string, boolean>?
---@field notify_errors boolean?
---@field pending_request_count_max integer?
---@field preview_height_fraction number?
---@field preview_margin integer?
---@field preview_row integer?
---@field preview_width_fraction number?
---@field preview_zindex integer?

---@class ImagePreviewConfig
---@field allow_http boolean
---@field cache_entry_count_max integer
---@field debounce_ms integer
---@field enabled boolean
---@field image_bytes_max integer
---@field markdown_filetypes table<string, boolean>
---@field notify_errors boolean
---@field pending_request_count_max integer
---@field preview_height_fraction number
---@field preview_margin integer
---@field preview_row integer
---@field preview_width_fraction number
---@field preview_zindex integer

---@class ImagePreviewState
---@field augroup_id integer?
---@field buf integer?
---@field cache table<string, string>
---@field cache_keys string[]
---@field enabled boolean
---@field generation_id integer
---@field img any
---@field path string?
---@field pending_request_count integer
---@field timer uv.uv_timer_t?
---@field win integer?

---@type ImagePreviewConfig
local config = {
  allow_http = false,
  cache_entry_count_max = CACHE_ENTRY_COUNT_MAX_DEFAULT,
  debounce_ms = DEBOUNCE_MS_DEFAULT,
  enabled = false,
  image_bytes_max = IMAGE_BYTES_MAX_DEFAULT,
  markdown_filetypes = {
    markdown = true,
    ['markdown.mdx'] = true,
  },
  notify_errors = false,
  pending_request_count_max = PENDING_REQUEST_COUNT_MAX_DEFAULT,
  preview_height_fraction = PREVIEW_HEIGHT_FRACTION_DEFAULT,
  preview_margin = PREVIEW_MARGIN_DEFAULT,
  preview_row = PREVIEW_ROW_DEFAULT,
  preview_width_fraction = PREVIEW_WIDTH_FRACTION_DEFAULT,
  preview_zindex = PREVIEW_ZINDEX_DEFAULT,
}

---@type ImagePreviewState
M.state = {
  augroup_id = nil,
  buf = nil,
  cache = {},
  cache_keys = {},
  enabled = false,
  generation_id = 0,
  img = nil,
  path = nil,
  pending_request_count = 0,
  timer = nil,
  win = nil,
}
---@param value any
---@return boolean
local function is_integer(value)
  if type(value) ~= 'number' then
    return false
  end

  if value ~= value then
    return false
  end

  if value == math.huge then
    return false
  end
  if value == -math.huge then
    return false
  end
  return math.floor(value) == value
end

---@param message string
local function notify_error(message)
  assert(type(message) == 'string')

  if not config.notify_errors then
    return
  end

  vim.notify(message, vim.log.levels.WARN, {
    title = 'Image Preview',
  })
end

---@return boolean
local function has_image_api()
  if type(vim.ui) ~= 'table' then
    return false
  end

  if type(image_api) ~= 'table' then
    return false
  end

  return type(image_api.open) == 'function'
end

---@param options ImagePreviewOptions?
---@return boolean? ok
---@return string? error_message
local function validate_options(options)
  if options == nil then
    return true, nil
  end

  if type(options) ~= 'table' then
    return nil, 'options must be a table'
  end

  if options.allow_http ~= nil and type(options.allow_http) ~= 'boolean' then
    return nil, 'allow_http must be a boolean'
  end

  if options.enabled ~= nil and type(options.enabled) ~= 'boolean' then
    return nil, 'enabled must be a boolean'
  end

  if options.notify_errors ~= nil and type(options.notify_errors) ~= 'boolean' then
    return nil, 'notify_errors must be a boolean'
  end

  if options.cache_entry_count_max ~= nil then
    if not is_integer(options.cache_entry_count_max) then
      return nil, 'cache_entry_count_max must be an integer'
    end

    if options.cache_entry_count_max <= 0 then
      return nil, 'cache_entry_count_max must be greater than zero'
    end
  end

  if options.debounce_ms ~= nil then
    if not is_integer(options.debounce_ms) then
      return nil, 'debounce_ms must be an integer'
    end

    if options.debounce_ms <= 0 then
      return nil, 'debounce_ms must be greater than zero'
    end
  end

  if options.image_bytes_max ~= nil then
    if not is_integer(options.image_bytes_max) then
      return nil, 'image_bytes_max must be an integer'
    end

    if options.image_bytes_max <= 0 then
      return nil, 'image_bytes_max must be greater than zero'
    end
  end

  if options.pending_request_count_max ~= nil then
    if not is_integer(options.pending_request_count_max) then
      return nil, 'pending_request_count_max must be an integer'
    end

    if options.pending_request_count_max <= 0 then
      return nil, 'pending_request_count_max must be greater than zero'
    end
  end

  if options.preview_margin ~= nil then
    if not is_integer(options.preview_margin) then
      return nil, 'preview_margin must be an integer'
    end

    if options.preview_margin <= 0 then
      return nil, 'preview_margin must be greater than zero'
    end
  end

  if options.preview_row ~= nil then
    if not is_integer(options.preview_row) then
      return nil, 'preview_row must be an integer'
    end

    if options.preview_row <= 0 then
      return nil, 'preview_row must be greater than zero'
    end
  end
  if options.preview_zindex ~= nil then
    if not is_integer(options.preview_zindex) then
      return nil, 'preview_zindex must be an integer'
    end

    if options.preview_zindex <= 0 then
      return nil, 'preview_zindex must be greater than zero'
    end
  end

  if options.preview_height_fraction ~= nil then
    if type(options.preview_height_fraction) ~= 'number' then
      return nil, 'preview_height_fraction must be a number'
    end

    if options.preview_height_fraction <= 0 then
      return nil, 'preview_height_fraction must be greater than zero'
    end

    if options.preview_height_fraction >= 1 then
      return nil, 'preview_height_fraction must be less than one'
    end
  end

  if options.preview_width_fraction ~= nil then
    if type(options.preview_width_fraction) ~= 'number' then
      return nil, 'preview_width_fraction must be a number'
    end

    if options.preview_width_fraction <= 0 then
      return nil, 'preview_width_fraction must be greater than zero'
    end

    if options.preview_width_fraction >= 1 then
      return nil, 'preview_width_fraction must be less than one'
    end
  end

  if options.markdown_filetypes ~= nil and type(options.markdown_filetypes) ~= 'table' then
    return nil, 'markdown_filetypes must be a table'
  end

  return true, nil
end

local function validate_config()
  assert(type(config.allow_http) == 'boolean')
  assert(type(config.enabled) == 'boolean')
  assert(type(config.markdown_filetypes) == 'table')
  assert(type(config.notify_errors) == 'boolean')

  assert(is_integer(config.cache_entry_count_max))
  assert(is_integer(config.debounce_ms))
  assert(is_integer(config.image_bytes_max))
  assert(is_integer(config.pending_request_count_max))
  assert(is_integer(config.preview_margin))
  assert(is_integer(config.preview_row))
  assert(is_integer(config.preview_zindex))

  assert(config.cache_entry_count_max > 0)
  assert(config.debounce_ms > 0)
  assert(config.image_bytes_max > 0)
  assert(config.pending_request_count_max > 0)
  assert(config.preview_margin > 0)
  assert(config.preview_row > 0)
  assert(config.preview_zindex > 0)

  assert(type(config.preview_height_fraction) == 'number')
  assert(type(config.preview_width_fraction) == 'number')
  assert(config.preview_height_fraction > 0)
  assert(config.preview_height_fraction < 1)
  assert(config.preview_width_fraction > 0)
  assert(config.preview_width_fraction < 1)
end

---@param path any
---@return boolean
local function is_image_path(path)
  if type(path) ~= 'string' then
    return false
  end
  local path_string = tostring(path)
  local path_lower = string.lower(path_string)
  if path_lower:match('%.avif$') ~= nil then
    return true
  end
  if path_lower:match('%.gif$') ~= nil then
    return true
  end
  if path_lower:match('%.jpe?g$') ~= nil then
    return true
  end
  if path_lower:match('%.png$') ~= nil then
    return true
  end
  if path_lower:match('%.svg$') ~= nil then
    return true
  end

  if path_lower:match('%.webp$') ~= nil then
    return true
  end

  return false
end

---@param source string
---@return boolean
local function is_remote_url(source)
  assert(type(source) == 'string')

  return source:match('^https?://') ~= nil
end

---@param source string
---@return boolean
local function is_https_url(source)
  assert(type(source) == 'string')

  return source:match('^https://') ~= nil
end

---@param source string
---@return boolean
local function is_absolute_path(source)
  assert(type(source) == 'string')

  if source:match('^/') ~= nil then
    return true
  end

  if source:match('^~') ~= nil then
    return true
  end

  if source:match('^%a:[/\\]') ~= nil then
    return true
  end

  return source:match('^\\\\') ~= nil
end

---@param bufnr integer
---@return boolean
local function is_markdown_buffer(bufnr)
  assert(type(bufnr) == 'number')

  if not api.nvim_buf_is_valid(bufnr) then
    return false
  end

  return config.markdown_filetypes[vim.bo[bufnr].filetype] == true
end

---@return string?
local function current_image_path()
  local path = api.nvim_buf_get_name(0)

  if not is_image_path(path) then
    return nil
  end

  return path
end

---@param line string
---@return string?
local function parse_markdown_image(line)
  assert(type(line) == 'string')

  local _, raw_target = line:match('!%[([^%]]*)%]%((.-)%)')

  if raw_target == nil then
    return nil
  end

  local target = vim.trim(raw_target)

  if target == '' then
    return nil
  end
  local bracketed_target = target:match('^<([^>]+)>')
  if bracketed_target ~= nil then
    target = bracketed_target
  else
    target = target:match('^([^%s]+)')
  end

  if target == nil or target == '' then
    return nil
  end

  return target
end

---@return string?
local function markdown_image_source()
  local bufnr = api.nvim_get_current_buf()

  if not is_markdown_buffer(bufnr) then
    return nil
  end

  return parse_markdown_image(api.nvim_get_current_line())
end

---@param source string
---@return boolean? ok
---@return string? error_message
local function validate_source(source)
  assert(type(source) == 'string')

  if source == '' then
    return nil, 'image source must not be empty'
  end

  if string.find(source, '%z') ~= nil then
    return nil, 'image source contains a NUL byte'
  end

  return true, nil
end

---@param source string
---@param bufnr integer
---@return string
local function resolve_local_path(source, bufnr)
  assert(type(source) == 'string')
  assert(type(bufnr) == 'number')

  local source_expanded = fn.expand(source)

  if is_absolute_path(source_expanded) then
    return fs.normalize(source_expanded)
  end

  local buffer_path = api.nvim_buf_get_name(bufnr)

  if buffer_path == '' then
    return fs.normalize(fn.fnamemodify(source_expanded, ':p'))
  end

  local buffer_directory = fn.fnamemodify(buffer_path, ':h')

  return fs.normalize(fs.joinpath(buffer_directory, source_expanded))
end
---@param key string
local function cache_remove_key(key)
  assert(type(key) == 'string')

  for index = 1, #M.state.cache_keys do
    if M.state.cache_keys[index] == key then
      table.remove(M.state.cache_keys, index)
      return
    end
  end
end

---@param key string
---@return string?
local function cache_get(key)
  assert(type(key) == 'string')

  local blob = M.state.cache[key]

  if blob == nil then
    return nil
  end

  cache_remove_key(key)
  M.state.cache_keys[#M.state.cache_keys + 1] = key

  return blob
end

---@param key string
---@param blob string
local function cache_put(key, blob)
  assert(type(key) == 'string')
  assert(type(blob) == 'string')
  assert(#blob > 0)
  assert(#blob <= config.image_bytes_max)

  if M.state.cache[key] ~= nil then
    cache_remove_key(key)
  end

  M.state.cache[key] = blob
  M.state.cache_keys[#M.state.cache_keys + 1] = key

  while #M.state.cache_keys > config.cache_entry_count_max do
    local evicted_key = table.remove(M.state.cache_keys, 1)

    assert(evicted_key ~= nil)

    M.state.cache[evicted_key] = nil
  end
  assert(#M.state.cache_keys <= config.cache_entry_count_max)
end
---@param blob string
---@return string? image_blob
---@return string? error_message
local function validate_blob(blob)
  if type(blob) ~= 'string' then
    return nil, 'image data is not a string'
  end

  if #blob == 0 then
    return nil, 'image data is empty'
  end

  if #blob > config.image_bytes_max then
    return nil, ('image exceeds configured limit of %d bytes'):format(config.image_bytes_max)
  end

  return blob, nil
end
---@param path string
---@param callback fun(blob: string?, error_message: string?)
local function read_local_blob(path, callback)
  assert(type(path) == 'string')
  assert(type(callback) == 'function')

  if fn.filereadable(path) ~= 1 then
    callback(nil, 'local image is not readable: ' .. path)
    return
  end

  local read_ok, blob_or_error = pcall(fn.readblob, path)

  if not read_ok then
    callback(nil, 'failed to read local image: ' .. tostring(blob_or_error))
    return
  end

  local blob, validation_error = validate_blob(blob_or_error)

  if blob == nil then
    callback(nil, validation_error)
    return
  end

  callback(blob, nil)
end

---@param url string
---@param callback fun(blob: string?, error_message: string?)
local function read_remote_blob(url, callback)
  assert(type(url) == 'string')
  assert(type(callback) == 'function')

  if not is_https_url(url) and not config.allow_http then
    callback(nil, 'refusing non-HTTPS image URL')
    return
  end

  if M.state.pending_request_count >= config.pending_request_count_max then
    callback(nil, 'remote image request limit reached')
    return
  end

  if type(network_api) ~= 'table' or type(network_api.request) ~= 'function' then
    callback(nil, 'vim.net.request is unavailable in this Neovim build')
    return
  end

  M.state.pending_request_count = M.state.pending_request_count + 1

  network_api.request(url, {}, function(request_error, response)
    M.state.pending_request_count = M.state.pending_request_count - 1

    if M.state.pending_request_count < 0 then
      M.state.pending_request_count = 0
    end

    if request_error ~= nil then
      callback(nil, 'remote image request failed: ' .. tostring(request_error))
      return
    end

    if type(response) ~= 'table' then
      callback(nil, 'remote image request returned no response')
      return
    end

    ---@type any
    local response_table = response

    local body = rawget(response_table, 'body')

    if type(body) ~= 'string' then
      callback(nil, 'remote image response has no body')
      return
    end

    local blob, validation_error = validate_blob(body)

    if blob == nil then
      callback(nil, validation_error)
      return
    end

    callback(blob, nil)
  end)
end

---@param source string
---@param callback fun(blob: string?, error_message: string?)
local function get_blob(source, callback)
  assert(type(source) == 'string')
  assert(type(callback) == 'function')

  local cached_blob = cache_get(source)

  if cached_blob ~= nil then
    callback(cached_blob, nil)
    return
  end

  local function complete(blob, read_error)
    if blob == nil then
      callback(nil, read_error)
      return
    end

    cache_put(source, blob)
    callback(blob, nil)
  end

  if is_remote_url(source) then
    read_remote_blob(source, complete)
    return
  end

  read_local_blob(source, complete)
end

local function clear_image()
  local image = M.state.img

  M.state.img = nil
  M.state.path = nil

  if image == nil then
    return
  end

  if type(image.clear) == 'function' then
    pcall(image.clear, image)
    return
  end

  if type(image.delete) == 'function' then
    pcall(image.delete, image)
    return
  end

  if type(image_api) == 'table' and type(image_api.clear) == 'function' then
    pcall(image_api.clear, image)
  end
end

local function close_preview_window()
  clear_image()

  if M.state.win ~= nil and api.nvim_win_is_valid(M.state.win) then
    pcall(api.nvim_win_close, M.state.win, true)
  end

  M.state.win = nil
  M.state.buf = nil
end

---@return integer width
---@return integer height
local function preview_dimensions()
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight

  assert(editor_width > 0)
  assert(editor_height > 0)

  local width = math.floor(editor_width * config.preview_width_fraction)
  local height = math.floor(editor_height * config.preview_height_fraction)

  width = math.max(1, math.min(width, editor_width - (config.preview_margin * 2)))
  height = math.max(1, math.min(height, editor_height - (config.preview_margin * 2)))

  return width, height
end
---@return integer
local function ensure_preview_window()
  if M.state.win ~= nil and api.nvim_win_is_valid(M.state.win) then
    return M.state.win
  end

  local width, height = preview_dimensions()
  local editor_width = vim.o.columns

  local buffer = api.nvim_create_buf(false, true)

  api.nvim_set_option_value('bufhidden', 'wipe', {
    buf = buffer,
  })

  api.nvim_set_option_value('buftype', 'nofile', {
    buf = buffer,
  })

  local window = api.nvim_open_win(buffer, false, {
    border = 'rounded',
    col = math.max(config.preview_margin, editor_width - width - config.preview_margin),
    focusable = false,
    height = height,
    noautocmd = true,
    relative = 'editor',
    row = config.preview_row,
    style = 'minimal',
    title = ' Image Preview ',
    title_pos = 'center',
    width = width,
    zindex = config.preview_zindex,
  })

  api.nvim_set_option_value('winblend', 0, {
    win = window,
  })

  M.state.buf = buffer
  M.state.win = window

  return window
end

---@param path string
---@return boolean? ok
---@return string? error_message
local function show_path(path)
  assert(type(path) == 'string')

  if not has_image_api() then
    return nil, 'vim.ui.img.open is unavailable in this Neovim build'
  end

  local window = ensure_preview_window()

  clear_image()

  local open_ok, image_or_error = pcall(image_api.open, path)

  if not open_ok then
    return nil, 'failed to open image: ' .. tostring(image_or_error)
  end

  if image_or_error == nil then
    return nil, 'image API returned no image object'
  end

  local image = image_or_error

  if type(image.show) ~= 'function' then
    return nil, 'image object does not expose show()'
  end

  local show_ok, show_error = pcall(image.show, image, {
    win = window,
  })

  if not show_ok then
    if type(image.clear) == 'function' then
      pcall(image.clear, image)
    end

    return nil, 'failed to display image: ' .. tostring(show_error)
  end

  M.state.img = image
  M.state.path = path

  return true, nil
end

---@param source string
---@param blob string
---@return boolean? ok
---@return string? error_message
local function show_blob(source, blob)
  assert(type(source) == 'string')
  assert(type(blob) == 'string')

  if type(image_api) ~= 'table' or type(image_api.set) ~= 'function' then
    return nil, 'vim.ui.img.set is unavailable in this Neovim build'
  end

  local window = ensure_preview_window()

  clear_image()

  local set_ok, image_or_error = pcall(image_api.set, blob, {
    win = window,
  })

  if not set_ok then
    return nil, 'failed to create image preview: ' .. tostring(image_or_error)
  end

  if image_or_error == nil then
    return nil, 'image API returned no image object'
  end

  M.state.img = image_or_error
  M.state.path = source

  return true, nil
end

local function invalidate_preview()
  M.state.generation_id = M.state.generation_id + 1

  clear_image()
end

---@return boolean
local function refresh_image_buffer()
  local path = current_image_path()

  if path == nil then
    return false
  end

  if path == M.state.path and M.state.img ~= nil then
    return true
  end

  local render_ok, render_error = show_path(path)

  if not render_ok then
    notify_error(render_error or 'failed to render image buffer')
    return false
  end

  return true
end

---@return boolean
local function refresh_markdown_image()
  local bufnr = api.nvim_get_current_buf()
  local source = markdown_image_source()

  if source == nil then
    return false
  end

  local source_valid, source_error = validate_source(source)

  if not source_valid then
    notify_error(source_error or 'invalid image source')
    return false
  end

  if not is_remote_url(source) then
    source = resolve_local_path(source, bufnr)
  end

  if source == M.state.path and M.state.img ~= nil then
    return true
  end

  M.state.generation_id = M.state.generation_id + 1

  local request_generation_id = M.state.generation_id
  local request_bufnr = bufnr
  local request_window = api.nvim_get_current_win()

  get_blob(source, function(blob, read_error)
    vim.schedule(function()
      if request_generation_id ~= M.state.generation_id then
        return
      end

      if not M.state.enabled then
        return
      end

      if not api.nvim_buf_is_valid(request_bufnr) then
        return
      end

      if not api.nvim_win_is_valid(request_window) then
        return
      end

      if api.nvim_get_current_buf() ~= request_bufnr then
        return
      end

      if api.nvim_get_current_win() ~= request_window then
        return
      end

      if blob == nil then
        notify_error(read_error or 'failed to read image')
        return
      end

      local render_ok, render_error = show_blob(source, blob)

      if not render_ok then
        notify_error(render_error or 'failed to render image')
      end
    end)
  end)

  return true
end

function M.refresh()
  if not M.state.enabled then
    return
  end
  local image_path = current_image_path()
  if image_path ~= nil then
    refresh_image_buffer()
    return
  end
  if markdown_image_source() ~= nil then
    refresh_markdown_image()
    return
  end
  invalidate_preview()
end
local function refresh_debounced()
  local timer = M.state.timer
  if timer == nil then
    return
  end
  if type(timer.is_closing) ~= 'function' then
    return
  end
  if timer:is_closing() then
    return
  end
  if type(timer.stop) ~= 'function' then
    return
  end
  if type(timer.start) ~= 'function' then
    return
  end
  timer:stop()
  timer:start(
    config.debounce_ms,
    0,
    vim.schedule_wrap(function()
      M.refresh()
    end)
  )
end

---@param path string?
function M.render(path)
  if not M.state.enabled then
    return
  end

  if path == nil then
    M.refresh()
    return
  end

  local path_valid, path_error = validate_source(path)

  if not path_valid then
    notify_error(path_error or 'invalid image path')
    return
  end

  if is_remote_url(path) then
    M.state.generation_id = M.state.generation_id + 1

    local request_generation_id = M.state.generation_id

    get_blob(path, function(blob, read_error)
      vim.schedule(function()
        if request_generation_id ~= M.state.generation_id then
          return
        end

        if not M.state.enabled then
          return
        end

        if blob == nil then
          notify_error(read_error or 'failed to load remote image')
          return
        end

        local render_ok, render_error = show_blob(path, blob)

        if not render_ok then
          notify_error(render_error or 'failed to render remote image')
        end
      end)
    end)

    return
  end

  local path_expanded = fn.expand(path)

  if fn.filereadable(path_expanded) ~= 1 then
    notify_error('local image is not readable: ' .. path_expanded)
    return
  end

  local render_ok, render_error = show_path(path_expanded)

  if not render_ok then
    notify_error(render_error or 'failed to render local image')
  end
end

function M.clear()
  invalidate_preview()
end

function M.toggle()
  M.state.enabled = not M.state.enabled

  if not M.state.enabled then
    close_preview_window()
    return
  end

  M.refresh()
end

local function create_commands()
  api.nvim_create_user_command('ImagePreviewToggle', function()
    M.toggle()
  end, {
    desc = 'Toggle image preview',
    force = true,
  })

  api.nvim_create_user_command('ImagePreviewRefresh', function()
    M.refresh()
  end, {
    desc = 'Refresh image preview',
    force = true,
  })

  api.nvim_create_user_command('ImagePreviewClear', function()
    M.clear()
  end, {
    desc = 'Clear image preview',
    force = true,
  })
end

local function create_autocmds()
  assert(M.state.augroup_id ~= nil)

  api.nvim_create_autocmd({
    'BufEnter',
    'WinEnter',
  }, {
    callback = refresh_debounced,
    desc = 'Refresh image preview for image and Markdown buffers',
    group = M.state.augroup_id,
  })

  api.nvim_create_autocmd('CursorMoved', {
    callback = function()
      local bufnr = api.nvim_get_current_buf()

      if is_markdown_buffer(bufnr) then
        refresh_debounced()
      end
    end,
    desc = 'Preview Markdown image under cursor',
    group = M.state.augroup_id,
  })

  api.nvim_create_autocmd({
    'BufLeave',
    'BufWipeout',
    'WinLeave',
  }, {
    callback = function()
      M.clear()
    end,
    desc = 'Clear inactive image preview',
    group = M.state.augroup_id,
  })

  api.nvim_create_autocmd('VimResized', {
    callback = function()
      if not M.state.enabled then
        return
      end

      close_preview_window()
      refresh_debounced()
    end,
    desc = 'Recreate image preview after editor resize',
    group = M.state.augroup_id,
  })
end

local function close_timer()
  local timer = M.state.timer

  M.state.timer = nil

  if timer == nil then
    return
  end

  if type(timer.is_closing) == 'function' and timer:is_closing() then
    return
  end

  if type(timer.stop) == 'function' then
    timer:stop()
  end

  if type(timer.close) == 'function' then
    timer:close()
  end
end

function M.teardown()
  M.clear()
  close_preview_window()
  close_timer()

  if M.state.augroup_id ~= nil then
    pcall(api.nvim_del_augroup_by_id, M.state.augroup_id)
    M.state.augroup_id = nil
  end

  M.state.cache = {}
  M.state.cache_keys = {}
  M.state.pending_request_count = 0
end

---@param options ImagePreviewOptions?
function M.setup(options)
  local options_valid, options_error = validate_options(options)

  if not options_valid then
    error('config.ui.image setup failed: ' .. (options_error or 'invalid options'))
  end

  config = vim.tbl_deep_extend('force', config, options or {})

  validate_config()

  M.teardown()

  if type(vim.uv) ~= 'table' or type(vim.uv.new_timer) ~= 'function' then
    error('config.ui.image setup failed: vim.uv.new_timer is unavailable')
  end

  ---@type uv.uv_timer_t?
  local timer_optional = vim.uv.new_timer()

  if timer_optional == nil then
    error('config.ui.image setup failed: unable to create debounce timer')
  end

  ---@type uv.uv_timer_t
  local timer = timer_optional

  M.state.augroup_id = api.nvim_create_augroup(AUGROUP_NAME, {
    clear = true,
  })
  M.state.enabled = config.enabled
  M.state.timer = timer

  create_commands()
  create_autocmds()

  if M.state.enabled then
    refresh_debounced()
  end
end

return M
